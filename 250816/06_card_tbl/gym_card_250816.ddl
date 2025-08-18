-- =========================================================
-- 🔧 공통: 스키마 고정(DDL에 스키마 접두어가 없음)
-- =========================================================
-- ALTER SESSION SET CURRENT_SCHEMA = gym;

--------------------------------------------------------------------------------
-- 0) 초기화(선택): 기존 트리거/인덱스/테이블 제거 
-- 에러 초기화 목적
--------------------------------------------------------------------------------
/*
BEGIN
  EXECUTE IMMEDIATE 'DROP TRIGGER trg_card_require_main_on_del';
EXCEPTION WHEN OTHERS THEN IF SQLCODE != -4080 THEN RAISE; END IF;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TRIGGER trg_card_require_main_on_upd';
EXCEPTION WHEN OTHERS THEN IF SQLCODE != -4080 THEN RAISE; END IF;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP INDEX uidx_card_one_main_per_member';
EXCEPTION WHEN OTHERS THEN IF SQLCODE NOT IN (-1418,-942) THEN RAISE; END IF;
END;
/
-- DROP TABLE card_tbl CASCADE CONSTRAINTS;
*/

--------------------------------------------------------------------------------
-- 1) 결제카드정보(card_tbl) 생성
--    - 엑셀 사양 1:1 반영: PK/NOT NULL/UNIQUE(card_number)/CHECK(Y,N)/FK(member)
--------------------------------------------------------------------------------
CREATE TABLE card_tbl (
    card_id       NUMBER        NOT NULL,                  -- 카드 고유번호 (PK)
    member_id     VARCHAR2(20)  NOT NULL,                  -- 소유자 회원ID (FK → member_tbl.member_id)
    card_bank     VARCHAR2(50)  NOT NULL,                  -- 카드사명 (신한, 현대 등)
    card_number   VARCHAR2(20)  NOT NULL,                  -- 카드번호(전역 UNIQUE)
    card_approval VARCHAR2(20),                            -- 승인번호(모의결제 등)
    card_main     CHAR(1)       DEFAULT 'N' NOT NULL,      -- 대표카드 여부(Y/N) - 기본값 'N'
    card_reg_date DATE          DEFAULT SYSDATE            -- 등록일 - 기본값 SYSDATE
);

-- 📌 컬럼 주석(엑셀 사양 그대로)
COMMENT ON COLUMN card_tbl.card_id       IS '카드 고유번호 (PK)';
COMMENT ON COLUMN card_tbl.member_id     IS '카드 소유자 회원 ID (FK)';
COMMENT ON COLUMN card_tbl.card_bank     IS '카드사명 (신한, 현대 등)';
COMMENT ON COLUMN card_tbl.card_number   IS '카드번호';
COMMENT ON COLUMN card_tbl.card_approval IS '카드 승인번호';
COMMENT ON COLUMN card_tbl.card_main     IS '대표 카드 여부 (Y/N)';
COMMENT ON COLUMN card_tbl.card_reg_date IS '카드 등록일';

-- 📌 제약조건
ALTER TABLE card_tbl ADD CONSTRAINT card_tbl_pk  PRIMARY KEY (card_id);            -- PK
ALTER TABLE card_tbl ADD CONSTRAINT card_main_ch CHECK (card_main IN ('Y','N'));   -- 대표여부 Y/N
ALTER TABLE card_tbl ADD CONSTRAINT card_number_un UNIQUE (card_number);           -- 카드번호 전역 UNIQUE

-- 📌 FK
ALTER TABLE card_tbl
  ADD CONSTRAINT fk_card_member
  FOREIGN KEY (member_id)
  REFERENCES member_tbl(member_id);

--------------------------------------------------------------------------------
-- 2) “회원별 대표카드 정확히 1개” 강제
--    - (A) 함수기반 UNIQUE 인덱스: member_id 당 card_main='Y' 1개만 허용
--    - (B) 트리거: 대표카드가 0개가 되는 UPDATE/DELETE 금지
--------------------------------------------------------------------------------
-- (A) 함수기반 유니크 인덱스: card_main='Y' 인 행만 유니크 키 생성
--     'Y'가 아닌 행은 인덱스 키가 NULL → 중복 허용
CREATE UNIQUE INDEX uidx_card_one_main_per_member
  ON card_tbl ( CASE WHEN card_main = 'Y' THEN member_id END );

-- (B1) 대표행 삭제 방지
CREATE OR REPLACE TRIGGER trg_card_require_main_on_del
BEFORE DELETE ON card_tbl
FOR EACH ROW
DECLARE
    v_cnt NUMBER;
BEGIN
    IF :OLD.card_main = 'Y' THEN
        SELECT COUNT(*)
          INTO v_cnt
          FROM card_tbl
         WHERE member_id = :OLD.member_id
           AND card_main = 'Y'
           AND card_id  <> :OLD.card_id;

        IF v_cnt = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20041,
                '대표카드 최소 1개 유지 규칙 위반: 삭제 전 다른 대표카드를 먼저 지정하세요.'
            );
        END IF;
    END IF;
END;
/

-- (B2) 대표 → 보조 하향/소유자 이관 시 원 소유자 대표 0개 방지
CREATE OR REPLACE TRIGGER trg_card_require_main_on_upd
BEFORE UPDATE ON card_tbl
FOR EACH ROW
DECLARE
    v_cnt NUMBER;
BEGIN
    -- ① 'Y' → 'N'
    IF :OLD.card_main = 'Y' AND :NEW.card_main = 'N' THEN
        SELECT COUNT(*)
          INTO v_cnt
          FROM card_tbl
         WHERE member_id = :OLD.member_id
           AND card_main = 'Y'
           AND card_id  <> :OLD.card_id;

        IF v_cnt = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20042,
                '대표카드 최소 1개 유지 규칙 위반: 먼저 다른 카드를 대표로 지정한 후 본 카드를 해제하세요.'
            );
        END IF;
    END IF;

    -- ② 대표카드인 행을 다른 회원에게 이관(member_id 변경)
    IF :OLD.card_main = 'Y' AND :OLD.member_id <> :NEW.member_id THEN
        SELECT COUNT(*)
          INTO v_cnt
          FROM card_tbl
         WHERE member_id = :OLD.member_id
           AND card_main = 'Y'
           AND card_id  <> :OLD.card_id;

        IF v_cnt = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20043,
                '대표카드 이관 불가: 원 소유 회원이 대표카드 0개가 됩니다. 먼저 다른 대표카드를 지정하세요.'
            );
        END IF;
    END IF;
END;
/
-- SHOW ERRORS;

--------------------------------------------------------------------------------
-- 3) 더미 데이터(재실행 대비 삭제 후 삽입)
--------------------------------------------------------------------------------
DELETE FROM card_tbl WHERE card_id IN (1,2,3,4);
COMMIT;

-- hong1: 대표 1개 + 보조 1개
INSERT INTO card_tbl (card_id, member_id, card_bank, card_number, card_approval, card_main, card_reg_date)
VALUES (1, 'hong1', '신한카드', '9400-1111-2222-3333', 'APPR-1001', 'Y', SYSDATE);

INSERT INTO card_tbl (card_id, member_id, card_bank, card_number, card_approval, card_main, card_reg_date)
VALUES (2, 'hong1', '현대카드', '9400-4444-5555-6666', 'APPR-1002', 'N', SYSDATE);

-- hong2: 대표 1개
INSERT INTO card_tbl (card_id, member_id, card_bank, card_number, card_approval, card_main, card_reg_date)
VALUES (3, 'hong2', '국민카드', '5500-7777-8888-9999', 'APPR-2001', 'Y', SYSDATE);

-- (참고) 대표 중복 시도 → 함수기반 UNIQUE 충돌(ORA-00001)로 실패해야 정상
-- INSERT INTO card_tbl (card_id, member_id, card_bank, card_number, card_main) 
-- VALUES (4, '홍1', '롯데카드', '1234-0000-0000-0000', 'Y');

COMMIT;

--------------------------------------------------------------------------------
-- 4) 확인 조회
--------------------------------------------------------------------------------
SELECT
    c.card_id                              AS "카드번호(PK)",
    c.member_id                            AS "회원ID",
    c.card_bank                            AS "카드사",
    c.card_number                          AS "카드번호",
    NVL(c.card_approval,'-')               AS "승인번호",
    CASE c.card_main WHEN 'Y' THEN '대표' ELSE '보조' END AS "대표여부",
    TO_CHAR(c.card_reg_date,'YYYY-MM-DD HH24:MI') AS "등록일"
FROM card_tbl c
ORDER BY c.member_id, c.card_id;

--------------------------------------------------------------------------------
-- 5-1) 💀 데이터 초기화 (안전 모드) 💀
--      - 예제 더미(card_id 1~4 등)만 정리 / 구조·제약 유지
--------------------------------------------------------------------------------
DELETE FROM card_tbl WHERE card_id IN (1,2,3,4);
COMMIT;

--------------------------------------------------------------------------------
-- 5-2) 💀 ddl 블록까지 안전 삭제 💀
--      - 실제 구조 제거 (테스트 종료 시 사용)
--------------------------------------------------------------------------------
/*
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_card_require_main_on_del';  EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_card_require_main_on_upd';  EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP INDEX uidx_card_one_main_per_member';   EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE card_tbl CASCADE CONSTRAINTS';    EXCEPTION WHEN OTHERS THEN NULL; END;
/
*/
