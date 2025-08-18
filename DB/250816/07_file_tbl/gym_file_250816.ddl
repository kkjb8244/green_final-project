-- =========================================================
-- 🔧 공통: 스키마 고정 (DDL에 스키마 접두어 없음)
-- =========================================================
-- ALTER SESSION SET CURRENT_SCHEMA = gym;

--------------------------------------------------------------------------------
-- 0) 재실행 안전 드롭
--------------------------------------------------------------------------------
/*
BEGIN EXECUTE IMMEDIATE 'DROP TABLE file_tbl CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_file_id';
EXCEPTION WHEN OTHERS THEN IF SQLCODE != -2289 THEN RAISE; END IF; END;
/
*/

--------------------------------------------------------------------------------
-- 1) 첨부파일(file_tbl) 테이블 생성  ← 엑셀 사양 1:1 반영
--    * 외래키 연결 불필요(단순 저장소 역할)
--------------------------------------------------------------------------------
CREATE TABLE file_tbl (
    file_id           NUMBER         NOT NULL,                 -- 파일 고유번호(PK)
    file_target_type  VARCHAR2(20)   NOT NULL,                 -- 대상 종류(board/content/facility 등)
    file_target_id    VARCHAR2(20)   NOT NULL,                 -- 대상의 고유 ID(문자)
    file_name         VARCHAR2(200)  NOT NULL,                 -- 업로드 원본 파일명
    file_path         VARCHAR2(500)  NOT NULL,                 -- 서버/로컬 저장 경로
    file_type         VARCHAR2(50)   DEFAULT '본문' NOT NULL,  -- 파일 용도 ('썸네일'|'본문')
    file_ext          VARCHAR2(20),                             -- 확장자 (jpg, png, pdf 등)
    file_size         NUMBER,                                   -- 파일 크기(byte)
    file_reg_date     DATE           DEFAULT SYSDATE NOT NULL   -- 파일 등록일
);

COMMENT ON TABLE  file_tbl                  IS '첨부파일 정보(단순 저장소. FK 연결 불필요)';
COMMENT ON COLUMN file_tbl.file_id          IS '파일 고유번호 (PK)';
COMMENT ON COLUMN file_tbl.file_target_type IS '첨부 대상 종류 (board/content/facility 등)';
COMMENT ON COLUMN file_tbl.file_target_id   IS '첨부 대상의 고유 ID(문자, FK 아님)';
COMMENT ON COLUMN file_tbl.file_name        IS '원본 파일 이름';
COMMENT ON COLUMN file_tbl.file_path        IS '저장 경로(절대/상대/URL)';
COMMENT ON COLUMN file_tbl.file_type        IS '파일 용도 (''썸네일''|''본문'')';
COMMENT ON COLUMN file_tbl.file_ext         IS '확장자 (jpg, png, pdf 등)';
COMMENT ON COLUMN file_tbl.file_size        IS '파일 크기 (byte)';
COMMENT ON COLUMN file_tbl.file_reg_date    IS '파일 등록일';

ALTER TABLE file_tbl ADD CONSTRAINT file_tbl_pk  PRIMARY KEY (file_id);
ALTER TABLE file_tbl ADD CONSTRAINT file_type_CH CHECK (file_type IN ('썸네일','본문'));

-- 대상별 조회 성능 향상(권장)
CREATE INDEX idx_file_target ON file_tbl (file_target_type, file_target_id);

--------------------------------------------------------------------------------
-- 2) 시퀀스 생성
--------------------------------------------------------------------------------
CREATE SEQUENCE seq_file_id START WITH 1 INCREMENT BY 1;

--------------------------------------------------------------------------------
-- 3) (SYS에서 1회) OS 경로를 읽기 위한 DIRECTORY 객체 생성 + 권한 부여
--    - DB서버가 해당 폴더를 직접 읽을 수 있어야 함(로컬 PC 경로면 DB가 같은 PC에 있어야 함)
--    - 아래 3.1, 3.2는 SYSDBA로 실행 후, 다시 gym으로 접속해서 4) 실행
--------------------------------------------------------------------------------
-- 3.1  (SYS) 기존 DIRECTORY 삭제(있으면)
-- BEGIN EXECUTE IMMEDIATE 'DROP DIRECTORY IMG_DIR'; EXCEPTION WHEN OTHERS THEN NULL; END;
-- /

-- 3.2  (SYS) DIRECTORY 생성 및 읽기권한 부여
-- CREATE DIRECTORY IMG_DIR AS 'D:\team_project\DB_Table\ddl\07_file_tbl\images';
-- GRANT READ ON DIRECTORY IMG_DIR TO gym;

--------------------------------------------------------------------------------
-- 4) (gym) 실제 파일 1건을 메타로 INSERT
--    - 파일명/확장자 추출
--    - 파일 크기: IMG_DIR + BFILE 로 읽어옴(권한/경로가 유효할 때)
--    - file_target_type/id는 샘플로 'content','1001' 사용(업무에 맞게 교체)
--------------------------------------------------------------------------------
DECLARE
  v_file_name  VARCHAR2(200) := '8bitdo_pro_3.jpg';                             -- 파일명
  v_file_path  VARCHAR2(500) := '"D:\developer_project\DB_Table\ddl\07_file_tbl\images\'; -- 경로(마지막 \ 포함 권장)
  v_ext        VARCHAR2(20)  := REGEXP_SUBSTR('8bitdo_pro_3.jpg','[^.]+$');     -- 확장자: jpg
  v_size       NUMBER;
  v_bfile      BFILE;
BEGIN
  -- IMG_DIR/파일명으로 BFILE 핸들 생성(3단계에서 SYS가 만든 DIRECTORY 필수)
  v_bfile := BFILENAME('IMG_DIR', v_file_name);

  -- 실제 파일 크기 읽기 (가능한 경우)
  BEGIN
    DBMS_LOB.FILEOPEN(v_bfile, DBMS_LOB.FILE_READONLY);
    v_size := DBMS_LOB.GETLENGTH(v_bfile);
    DBMS_LOB.FILECLOSE(v_bfile);
  EXCEPTION
    WHEN OTHERS THEN
      -- 읽기 실패(경로 접근 불가 등) 시 크기는 NULL로 저장하고 계속 진행
      v_size := NULL;
  END;

  INSERT INTO file_tbl (
    file_id, file_target_type, file_target_id,
    file_name, file_path, file_type, file_ext, file_size
  ) VALUES (
    seq_file_id.NEXTVAL,
    'content',              -- ▶ 어느 모듈의 파일인지: 'board'|'content'|'facility' 등으로 교체 가능
    '1001',                 -- ▶ 대상의 고유 ID(문자값). 업무 PK에 맞게 교체
    v_file_name,
    v_file_path,
    '본문',                 -- ▶ 용도: '본문' 또는 '썸네일'
    v_ext,
    v_size
  );

  COMMIT;
END;
/

--------------------------------------------------------------------------------
-- 5) 확인
--------------------------------------------------------------------------------
SELECT file_id, file_target_type, file_target_id, file_name, file_ext, file_size,
       file_path,
       TO_CHAR(file_reg_date,'YYYY-MM-DD HH24:MI') AS reg_dt
  FROM file_tbl
 ORDER BY file_id;

-- (선택) 단순 INSERT 예시: BFILE/크기 계산 없이 바로 기록하고 싶을 때
-- INSERT INTO file_tbl (file_id,file_target_type,file_target_id,file_name,file_path,file_type,file_ext,file_size)
-- VALUES (seq_file_id.NEXTVAL, 'content', '1001', '8bitdo_pro_3.jpg',
--         'D:\team_project\DB_Table\ddl\07_file_tbl\images\', '본문', 'jpg', NULL);
-- COMMIT;

--------------------------------------------------------------------------------
-- 5-1) 💀 데이터 초기화 (안전 모드) 💀
--      - 샘플 데이터만 삭제 / 구조·제약 유지
--------------------------------------------------------------------------------
-- 예: 특정 target만 정리하고 싶으면 아래처럼 조건을 좁혀 사용
-- DELETE FROM file_tbl WHERE file_target_type='content' AND file_target_id='1001';
-- COMMIT;

-- 일괄 정리(주의: 전체 데이터 삭제)
-- DELETE FROM file_tbl;
-- COMMIT;

--------------------------------------------------------------------------------
-- 5-2) 💀 ddl 블록까지 안전 삭제 💀
--      - 실제 구조 제거 (테스트 종료 시 사용)
--------------------------------------------------------------------------------
/*
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_file_id';                      EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP INDEX idx_file_target';                      EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE file_tbl CASCADE CONSTRAINTS';        EXCEPTION WHEN OTHERS THEN NULL; END;
/
*/
