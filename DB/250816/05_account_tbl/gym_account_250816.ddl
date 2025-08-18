-- =========================================================
-- 🔧 공통: 스키마 고정(DDL에 스키마 접두어가 없음)
-- =========================================================
-- ALTER SESSION SET CURRENT_SCHEMA = gym;

--------------------------------------------------------------------------------
-- 1) 결제계좌정보(account_tbl) 생성
 --------------------------------------------------------------------------------
CREATE TABLE account_tbl (
    account_id       NUMBER        NOT NULL,                  -- 회원 계좌 고유번호 (PK)
    member_id        VARCHAR2(20)  NOT NULL,                  -- 계좌 소유자 회원 ID (FK → member_tbl.member_id)
    account_bank     VARCHAR2(50)  NOT NULL,                  -- 계좌 은행명 (국민, 카카오 등)
    account_number   VARCHAR2(20)  NOT NULL,                  -- 실제 계좌번호(전역 UNIQUE)
    account_main     CHAR(1)       DEFAULT 'N' NOT NULL,      -- 대표 계좌 여부(Y/N) - 기본값 'N'
    account_reg_date DATE          DEFAULT SYSDATE            -- 등록일 - 기본값 SYSDATE
);

-- 📌 컬럼 주석(엑셀 사양 그대로)
COMMENT ON COLUMN account_tbl.account_id       IS '회원 계좌 고유번호 (PK)';
COMMENT ON COLUMN account_tbl.member_id        IS '계좌 소유자 회원 ID (FK)';
COMMENT ON COLUMN account_tbl.account_bank     IS '계좌 은행명 (국민, 카카오 등)';
COMMENT ON COLUMN account_tbl.account_number   IS '실제 계좌번호';
COMMENT ON COLUMN account_tbl.account_main     IS '대표 계좌 여부 (Y/N)';
COMMENT ON COLUMN account_tbl.account_reg_date IS '등록일';

-- 📌 제약조건
ALTER TABLE account_tbl ADD CONSTRAINT account_tbl_pk  PRIMARY KEY (account_id);            -- PK
ALTER TABLE account_tbl ADD CONSTRAINT account_main_ch CHECK (account_main IN ('Y','N'));   -- 대표여부 Y/N
ALTER TABLE account_tbl ADD CONSTRAINT account_number_un UNIQUE (account_number);           -- 계좌번호 전역 UNIQUE (중복되면 에러 발생)

-- 📌 FK
ALTER TABLE account_tbl
  ADD CONSTRAINT fk_account_member
  FOREIGN KEY (member_id)
  REFERENCES member_tbl(member_id);

--------------------------------------------------------------------------------
-- 2) “회원별 대표계좌 정확히 1개” 강제
--    - (A) 함수기반 UNIQUE 인덱스: member_id 당 account_main='Y' 1개만 허용
--    - (B) 트리거: 대표계좌가 0개가 되는 UPDATE/DELETE 금지
 --------------------------------------------------------------------------------

-- (A) 함수기반 유니크 인덱스: account_main='Y'인 행만 대상
--     'Y'가 아닌 행은 인덱스 키가 NULL → 중복 허용
CREATE UNIQUE INDEX uidx_account_one_main_per_member
  ON account_tbl ( CASE WHEN account_main = 'Y' THEN member_id END );

-- (B1) 대표행 삭제 방지: 삭제하려는 행이 대표('Y')이고, 동일 회원의 다른 대표가 없으면 차단
CREATE OR REPLACE TRIGGER trg_account_require_main_on_del
BEFORE DELETE ON account_tbl
FOR EACH ROW
DECLARE
    v_cnt NUMBER;
BEGIN
    IF :OLD.account_main = 'Y' THEN
        SELECT COUNT(*)
          INTO v_cnt
          FROM account_tbl
         WHERE member_id   = :OLD.member_id
           AND account_main = 'Y'
           AND account_id  <> :OLD.account_id;

        IF v_cnt = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20031,
                '대표계좌 최소 1개 유지 규칙 위반: 삭제 전 다른 대표계좌를 먼저 지정해야 합니다.'
            );
        END IF;
    END IF;
END;
/

-- (B2) 대표 → 보조로 내릴 때 방지: UPDATE로 'Y'→'N' 변경 시, 동일 회원의 다른 대표가 없으면 차단
--     또한, 대표인 상태에서 member_id를 다른 회원으로 변경할 때도 기존 회원 쪽 대표 0개 방지
CREATE OR REPLACE TRIGGER trg_account_require_main_on_upd
BEFORE UPDATE ON account_tbl
FOR EACH ROW
DECLARE
    v_cnt NUMBER;
BEGIN
    -- ① 대표 → 보조로 내리는 경우('Y'→'N')
    IF :OLD.account_main = 'Y' AND :NEW.account_main = 'N' THEN
        SELECT COUNT(*)
          INTO v_cnt
          FROM account_tbl
         WHERE member_id   = :OLD.member_id
           AND account_main = 'Y'
           AND account_id  <> :OLD.account_id;

        IF v_cnt = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20032,
                '대표계좌 최소 1개 유지 규칙 위반: 먼저 다른 계좌를 대표로 지정한 후 본 계좌를 해제하세요.'
            );
        END IF;
    END IF;

    -- ② 대표인 행을 다른 회원에게 이관(member_id 변경)하는 경우: 원 소유자 측 대표 0개 방지
    IF :OLD.account_main = 'Y' AND :OLD.member_id <> :NEW.member_id THEN
        SELECT COUNT(*)
          INTO v_cnt
          FROM account_tbl
         WHERE member_id   = :OLD.member_id
           AND account_main = 'Y'
           AND account_id  <> :OLD.account_id;

        IF v_cnt = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20033,
                '대표계좌 이관 불가: 원 소유 회원이 대표계좌 0개가 됩니다. 먼저 다른 대표계좌를 지정하세요.'
            );
        END IF;
    END IF;
END;
/
-- SHOW ERRORS;

--------------------------------------------------------------------------------
-- 3) 더미 데이터(재실행 대비 삭제 후 삽입)
--------------------------------------------------------------------------------
DELETE FROM account_tbl WHERE account_id IN (1,2,3,4);
COMMIT;

-- hong1: 대표 1개 + 보조 2개
INSERT INTO account_tbl (account_id, member_id, account_bank, account_number, account_main, account_reg_date)
VALUES (1, 'hong1', '국민은행',   '123-456-789012', 'Y', SYSDATE);

INSERT INTO account_tbl (account_id, member_id, account_bank, account_number, account_main, account_reg_date)
VALUES (2, 'hong1', '카카오뱅크', '333-20-1234567', 'N', SYSDATE);

INSERT INTO account_tbl (account_id, member_id, account_bank, account_number, account_main, account_reg_date)
VALUES (3, 'hong1', '신한은행',   '110-123-456789', 'N', SYSDATE);

-- hong2: 대표 1개
INSERT INTO account_tbl (account_id, member_id, account_bank, account_number, account_main, account_reg_date)
VALUES (4, 'hong2', '농협은행',   '301-1234-567890', 'Y', SYSDATE);

COMMIT;

--------------------------------------------------------------------------------
-- 4) 확인 조회
--------------------------------------------------------------------------------
SELECT
    a.account_id                             AS "계좌번호(PK)",
    a.member_id                              AS "회원ID",
    a.account_bank                           AS "은행명",
    a.account_number                         AS "계좌번호",
    CASE a.account_main WHEN 'Y' THEN '대표' ELSE '보조' END AS "대표여부",
    TO_CHAR(a.account_reg_date,'YYYY-MM-DD HH24:MI') AS "등록일"
FROM account_tbl a
ORDER BY a.member_id, a.account_id;

--------------------------------------------------------------------------------
-- 5-1) 💀 데이터 초기화 (안전 모드) 💀
--      - 예제 더미(account_id 1~4 등)만 정리 / 구조·제약 유지
--------------------------------------------------------------------------------
DELETE FROM account_tbl WHERE account_id IN (1,2,3,4);
COMMIT;

--------------------------------------------------------------------------------
-- 5-2) 💀 ddl 블록까지 안전 삭제 💀
--      - 실제 구조 제거 (테스트 종료 시 사용)
--------------------------------------------------------------------------------
/*
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_account_require_main_on_del'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_account_require_main_on_upd'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP INDEX uidx_account_one_main_per_member';  EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE account_tbl CASCADE CONSTRAINTS';    EXCEPTION WHEN OTHERS THEN NULL; END;
/
*/

--------------------------------------------------------------------------------
-- (참고) 과거 파괴적 명령은 주석 처리(아래 두 줄은 동일 기능을 5-2 블록으로 대체)
--------------------------------------------------------------------------------
-- DROP TABLE account_tbl CASCADE CONSTRAINTS;
-- TRUNCATE TABLE account_tbl;
