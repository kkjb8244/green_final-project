-- =========================================================
-- 🔧 공통: 스키마 고정 (DDL에 스키마 접두어 없음)
-- =========================================================
-- ALTER SESSION SET CURRENT_SCHEMA = gym;

--------------------------------------------------------------------------------
-- 1) board_tbl 테이블 생성 
-- - 게시판 마스터(공지/FAQ 등) + 상단 노출 콘텐츠
--------------------------------------------------------------------------------
CREATE TABLE board_tbl (
    board_id       NUMBER         NOT NULL,                 -- 게시판 고유번호 (PK)
    board_title    VARCHAR2(50)   NOT NULL,                 -- 게시판 이름(공지사항 등)
    board_content  VARCHAR2(100)  NOT NULL,                 -- 게시판 상단내용
    board_use      CHAR(1)        DEFAULT 'Y' NOT NULL,     -- 사용여부('Y'/'N') 기본값 'Y'
    board_reg_date DATE           DEFAULT SYSDATE NOT NULL, -- 생성일자(기본값 SYSDATE)
    board_mod_date DATE,                                    -- 수정일자(수정 시 갱신)
    member_id      VARCHAR2(20)                               -- 작성자/담당자 회원ID(FK)
);

-- 컬럼/테이블 주석
COMMENT ON TABLE  board_tbl                IS '게시판(공지/FAQ 등) 마스터';
COMMENT ON COLUMN board_tbl.board_id       IS '게시판 고유번호(PK)';
COMMENT ON COLUMN board_tbl.board_title    IS '게시판 이름(공지사항 등)';
COMMENT ON COLUMN board_tbl.board_content  IS '게시판 상단내용';
COMMENT ON COLUMN board_tbl.board_use      IS '사용여부(기본값 Y)';
COMMENT ON COLUMN board_tbl.board_reg_date IS '생성일자(기본값 SYSDATE)';
COMMENT ON COLUMN board_tbl.board_mod_date IS '수정일자(수정 시 갱신)';
COMMENT ON COLUMN board_tbl.member_id      IS '작성자/담당자 회원ID(FK) — 생성/변경은 admin만 허용(트리거 강제)';

-- PK / CHECK 제약조건
ALTER TABLE board_tbl ADD CONSTRAINT board_tbl_pk   PRIMARY KEY (board_id);
ALTER TABLE board_tbl ADD CONSTRAINT board_use_CH   CHECK (board_use IN ('Y','N'));

--------------------------------------------------------------------------------
-- 2) FK 설정: board_tbl.member_id → member_tbl.member_id
--------------------------------------------------------------------------------
ALTER TABLE board_tbl
  ADD CONSTRAINT fk_board_member
  FOREIGN KEY (member_id)
  REFERENCES member_tbl(member_id);

--------------------------------------------------------------------------------
-- 3) 🔒 권한 강제 트리거
--    요구사항: "게시판 생성 권한은 member_role='admin' 계정만"
--    - INSERT: member_id가 반드시 존재해야 하며, 해당 회원의 member_role='admin' 이어야 함
--    - UPDATE OF member_id: 변경 대상도 member_role='admin' 이어야 함
--    - FK 미존재/NULL 등도 명확한 에러 메시지 제공
--------------------------------------------------------------------------------
BEGIN
  EXECUTE IMMEDIATE 'DROP TRIGGER trg_board_admin_only';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -4080 THEN RAISE; END IF;  -- ORA-04080(트리거 없음)만 무시
END;
/

CREATE OR REPLACE TRIGGER trg_board_admin_only
BEFORE INSERT OR UPDATE OF member_id ON board_tbl
FOR EACH ROW
DECLARE
  v_role member_tbl.member_role%TYPE;
BEGIN
  ----------------------------------------------------------------
  -- 1) INSERT 시: member_id는 반드시 지정되어야 함(생성자 표기 강제)
  ----------------------------------------------------------------
  IF INSERTING AND :NEW.member_id IS NULL THEN
    RAISE_APPLICATION_ERROR(
      -20021,
      '게시판 생성 시 member_id(작성자)를 반드시 지정해야 합니다. (admin 계정만 허용)'
    );
  END IF;

  -- member_id가 NULL이면 더 이상 검사 불필요 (UPDATE에서 NULL로 변경 허용 안 함 권장 시 아래 IF 제거)
  IF :NEW.member_id IS NULL THEN
    RETURN;
  END IF;

  ----------------------------------------------------------------
  -- 2) 대상 회원의 권한 조회
  ----------------------------------------------------------------
  SELECT member_role
    INTO v_role
    FROM member_tbl
   WHERE member_id = :NEW.member_id;

  ----------------------------------------------------------------
  -- 3) admin 권한 검사 (대소문자 무시)
  ----------------------------------------------------------------
  IF UPPER(NVL(v_role, '')) <> 'ADMIN' THEN
    RAISE_APPLICATION_ERROR(
      -20022,
      '게시판 생성/담당자 변경은 member_role=ADMIN 계정만 가능합니다.'
    );
  END IF;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(
      -20023,
      '지정한 member_id가 회원 테이블에 존재하지 않습니다.'
    );
END;
/
-- ✅ 결과: board_tbl INSERT/담당자 변경은 반드시 admin 계정으로만 가능

--------------------------------------------------------------------------------
-- 4) 더미 데이터 (재실행 대비 삭제 후 삽입)
--    - hong10: admin (앞서 만들어 둔 데이터 가정)
--    - hong1 : user  (테스트 실패용)
--------------------------------------------------------------------------------
DELETE FROM board_tbl WHERE board_id IN (1, 2);
COMMIT;

-- (성공) admin 계정(hong10)으로 생성
INSERT INTO board_tbl (
  board_id, board_title, board_content, board_use, board_reg_date, member_id
) VALUES (
  1, '공지사항', '시스템 공지 상단 안내', 'Y', SYSDATE, 'hong10'
);

-- (실패 예시) user 계정(hong1)으로 생성 시도 → ORA-20022
-- INSERT INTO board_tbl (board_id, board_title, board_content, board_use, board_reg_date, member_id)
-- VALUES (2, 'FAQ', 'FAQ 상단 안내', 'Y', SYSDATE, 'hong1');

COMMIT;

--------------------------------------------------------------------------------
-- 5) 확인 조회
--------------------------------------------------------------------------------
SELECT
    board_id                       AS "게시판ID",
    board_title                    AS "게시판명",
    board_content                  AS "상단내용",
    CASE board_use WHEN 'Y' THEN '사용' ELSE '미사용' END AS "사용여부",
    TO_CHAR(board_reg_date,'YYYY-MM-DD HH24:MI') AS "생성일",
    TO_CHAR(board_mod_date,'YYYY-MM-DD HH24:MI') AS "수정일",
    member_id                      AS "작성자ID(FK)"
FROM board_tbl
ORDER BY board_id;

--------------------------------------------------------------------------------
-- 6-1) 💀 데이터 초기화 (안전 모드) 💀
--      - 예제 더미(board_id 1,2 등)만 정리 / 구조·제약 유지
--------------------------------------------------------------------------------
DELETE FROM board_tbl WHERE board_id IN (1, 2);
COMMIT;

--------------------------------------------------------------------------------
-- 6-2) 💀 ddl 블록까지 안전 삭제 💀 
--      - 실제 구조 제거 (테스트 종료 시 사용)
--------------------------------------------------------------------------------
/*
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_board_admin_only'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE board_tbl CASCADE CONSTRAINTS';     EXCEPTION WHEN OTHERS THEN NULL; END;
/
*/
