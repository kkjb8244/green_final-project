-- =========================================================
-- 🔧 공통: 스키마 고정 (DDL에 스키마 접두어 없음)
-- =========================================================
-- ALTER SESSION SET CURRENT_SCHEMA = gym;

--------------------------------------------------------------------------------
-- 0) 재실행 안전 드롭
--------------------------------------------------------------------------------
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE post_tbl CASCADE CONSTRAINTS';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -942 THEN RAISE; END IF;  -- ORA-00942: 테이블 없음 → 무시
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE seq_post_id';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -2289 THEN RAISE; END IF; -- ORA-02289: 시퀀스 없음 → 무시
END;
/

--------------------------------------------------------------------------------
-- 1) post_tbl 테이블 생성 
--------------------------------------------------------------------------------
CREATE TABLE post_tbl (
    post_id         NUMBER          NOT NULL,                 -- 게시글 고유번호 (PK)
    board_id        NUMBER          NOT NULL,                 -- 게시판 ID (FK → board_tbl.board_id)
    post_title      VARCHAR2(200)   NOT NULL,                 -- 게시글 제목
    post_content    CLOB            NOT NULL,                 -- 게시글 내용 (HTML 가능)
    member_id       VARCHAR2(20)    NOT NULL,                 -- 작성자 ID (FK → member_tbl.member_id)
    post_reg_date   DATE DEFAULT SYSDATE NOT NULL,            -- 등록일 (기본값 SYSDATE)
    post_mod_date   DATE,                                     -- 수정일 (수정시 갱신)
    post_view_count NUMBER DEFAULT 0,                         -- 조회수 (기본값 0)
    post_notice     CHAR(1) DEFAULT 'N' NOT NULL,             -- 공지글 여부 ('Y'/'N') 기본값 'N'
    post_type       VARCHAR2(20) DEFAULT '일반' NOT NULL      -- 게시글 유형 ('공지','일반')
);

--------------------------------------------------------------------------------
-- 2) 컬럼/테이블 주석
--------------------------------------------------------------------------------
COMMENT ON TABLE  post_tbl                 IS '게시글';
COMMENT ON COLUMN post_tbl.post_id         IS '게시글 고유번호 (PK)';
COMMENT ON COLUMN post_tbl.board_id        IS '게시판 ID (FK → board_tbl.board_id)';
COMMENT ON COLUMN post_tbl.post_title      IS '게시글 제목';
COMMENT ON COLUMN post_tbl.post_content    IS '게시글 내용 (HTML 가능)';
COMMENT ON COLUMN post_tbl.member_id       IS '작성자 ID (FK → member_tbl.member_id)';
COMMENT ON COLUMN post_tbl.post_reg_date   IS '등록일 (기본값 SYSDATE)';
COMMENT ON COLUMN post_tbl.post_mod_date   IS '수정일 (수정시 갱신)';
COMMENT ON COLUMN post_tbl.post_view_count IS '조회수 (기본값 0)';
COMMENT ON COLUMN post_tbl.post_notice     IS '공지글 여부 (기본값 N)'; -- 프론트엔드에서 공지 여부 보여주는 역할
COMMENT ON COLUMN post_tbl.post_type       IS '게시글 유형 (공지/일반)';

--------------------------------------------------------------------------------
-- 3) 제약조건
--------------------------------------------------------------------------------
-- 게시글 id를 PK값으로 선정
ALTER TABLE post_tbl ADD CONSTRAINT post_tbl_pk PRIMARY KEY (post_id);

-- 게시판 id 외래키 설정
ALTER TABLE post_tbl ADD CONSTRAINT fk_post_board
  FOREIGN KEY (board_id) REFERENCES board_tbl(board_id);

-- 회원 id 외래키 설정
ALTER TABLE post_tbl ADD CONSTRAINT fk_post_member
  FOREIGN KEY (member_id) REFERENCES member_tbl(member_id);

-- 공지글 여부의 제약 조건 (기본값 N)
ALTER TABLE post_tbl ADD CONSTRAINT post_notice_CH
  CHECK (post_notice IN ('Y','N'));

-- 게시글 유형의 제약 조건 (기본값 일반)
ALTER TABLE post_tbl ADD CONSTRAINT post_type_CH
  CHECK (post_type IN ('공지','일반'));

--------------------------------------------------------------------------------
-- 4) 시퀀스 생성
--------------------------------------------------------------------------------
CREATE SEQUENCE seq_post_id
  START WITH 1
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;

--------------------------------------------------------------------------------
-- 5) 더미 데이터 생성
--------------------------------------------------------------------------------
-- 공지글 
INSERT INTO post_tbl (
    post_id, board_id, post_title, post_content, member_id, post_notice, post_type
) VALUES (
    seq_post_id.NEXTVAL, 1, '첫 번째 공지사항', '게시판 공지사항입니다.', 'hong10', 'Y', '공지'
);

-- 일반글
INSERT INTO post_tbl (
    post_id, board_id, post_title, post_content, member_id,  post_notice, post_type
) VALUES (
    seq_post_id.NEXTVAL, 1, '첫 번째 일반글', '일반 게시글 테스트입니다.', 'hong1', 'N', '일반'
);

COMMIT;

--------------------------------------------------------------------------------
-- 6) 확인 조회
--------------------------------------------------------------------------------
SELECT
    p.board_id         AS "게시판ID (FK)",
    p.post_id          AS "게시글ID (PK)",
    p.post_title       AS "제목",
    p.member_id        AS "작성자ID (FK)",
    CASE p.post_notice WHEN 'Y' THEN '공지' ELSE '일반' END AS "공지여부",
    p.post_type        AS "게시글유형",
    p.post_content     AS "게시글내용",
    p.post_view_count  AS "조회수",
    TO_CHAR(p.post_reg_date,'YYYY-MM-DD HH24:MI')           AS "등록일",
    NVL(TO_CHAR(p.post_mod_date,'YYYY-MM-DD HH24:MI'), '-') AS "수정일"
FROM post_tbl p
ORDER BY p.post_id;

--------------------------------------------------------------------------------
-- 7-1) 💀 데이터 초기화 (안전 모드) 💀
--      - 데이터만 삭제 / 구조·제약 유지
--------------------------------------------------------------------------------
DELETE FROM post_tbl;
COMMIT;

-- 시퀀스 재시작(선택): 기존 시퀀스가 있으면 삭제 후 1부터 다시 시작
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE seq_post_id';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -2289 THEN RAISE; END IF; -- ORA-02289: 시퀀스 없음 → 무시
END;
/
CREATE SEQUENCE seq_post_id START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

--------------------------------------------------------------------------------
-- 7-2) 💀 ddl 블록까지 안전 삭제 💀
--      - 실제 구조 제거 (테스트 종료 시 사용)
--------------------------------------------------------------------------------
/*
BEGIN EXECUTE IMMEDIATE 'DROP TABLE post_tbl CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_post_id';                 EXCEPTION WHEN OTHERS THEN NULL; END;
/
*/
