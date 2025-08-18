-- =========================================================
-- 🔧 공통: 스키마 고정 (DDL에 스키마 접두어 없음)
-- =========================================================
-- ALTER SESSION SET CURRENT_SCHEMA = gym;

--------------------------------------------------------------------------------
-- 1) facility_tbl 테이블 생성
--------------------------------------------------------------------------------
CREATE TABLE facility_tbl (
    facility_id         NUMBER         NOT NULL,                 -- 시설 고유 번호 (PK)
    facility_name       VARCHAR2(100)  NOT NULL,                 -- 시설명
    member_id           VARCHAR2(20)   NOT NULL,                 -- 관리자/강사 회원ID (FK)
    facility_phone      VARCHAR2(20),                            -- 연락처
    facility_content    CLOB,                                    -- 설명 HTML
    facility_image_path VARCHAR2(200),                           -- 이미지 경로
    facility_person_max NUMBER,                                  -- 최대 인원
    facility_person_min NUMBER,                                  -- 최소 인원
    facility_use        CHAR(1)        DEFAULT 'Y' NOT NULL,     -- 사용 여부 (Y/N), 기본값 'Y'
    facility_reg_date   DATE           DEFAULT SYSDATE NOT NULL, -- 등록일(기본값 SYSDATE)
    facility_mod_date   DATE,                                    -- 수정일(실제 UPDATE시에만 자동 세팅)
    facility_open_time  DATE,                                    -- 운영 시작 시간
    facility_close_time DATE                                     -- 운영 종료 시간
);

-- 컬럼/테이블 주석
COMMENT ON TABLE  facility_tbl                     IS '시설 마스터';
COMMENT ON COLUMN facility_tbl.facility_id         IS '시설 고유 번호';
COMMENT ON COLUMN facility_tbl.facility_name       IS '시설명';
COMMENT ON COLUMN facility_tbl.member_id           IS '강사ID(관리자ID)';
COMMENT ON COLUMN facility_tbl.facility_phone      IS '시설 연락처';
COMMENT ON COLUMN facility_tbl.facility_content    IS '설명 HTML 내용';
COMMENT ON COLUMN facility_tbl.facility_image_path IS '이미지 경로';
COMMENT ON COLUMN facility_tbl.facility_person_max IS '최대인원';
COMMENT ON COLUMN facility_tbl.facility_person_min IS '최소인원';
COMMENT ON COLUMN facility_tbl.facility_use        IS '사용 가능 여부(Y/N)';
COMMENT ON COLUMN facility_tbl.facility_reg_date   IS '시설 등록일';
COMMENT ON COLUMN facility_tbl.facility_mod_date   IS '시설 수정일(UPDATE 시에만 자동 기록)';
COMMENT ON COLUMN facility_tbl.facility_open_time  IS '운영 시작 시간';
COMMENT ON COLUMN facility_tbl.facility_close_time IS '운영 종료 시간';

-- PK / CHECK 제약조건
ALTER TABLE facility_tbl ADD CONSTRAINT facility_tbl_pk    PRIMARY KEY (facility_id);
ALTER TABLE facility_tbl ADD CONSTRAINT facility_use_ch    CHECK (facility_use IN ('Y','N'));
ALTER TABLE facility_tbl ADD CONSTRAINT facility_person_ch CHECK (facility_person_max >= facility_person_min);

--------------------------------------------------------------------------------
-- 2) FK 설정: facility_tbl.member_id → member_tbl.member_id
--------------------------------------------------------------------------------
ALTER TABLE facility_tbl
  ADD CONSTRAINT fk_facility_member
  FOREIGN KEY (member_id)
  REFERENCES member_tbl(member_id);

--------------------------------------------------------------------------------
-- 3) 트리거 #1 : 담당자 권한 검증
--------------------------------------------------------------------------------
BEGIN
  EXECUTE IMMEDIATE 'DROP TRIGGER trg_facility_insert';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -4080 THEN RAISE; END IF;  -- ORA-04080: 존재하지 않음 → 무시
END;
/

CREATE OR REPLACE TRIGGER trg_facility_insert
BEFORE INSERT OR UPDATE ON facility_tbl
FOR EACH ROW
DECLARE
    v_role       member_tbl.member_role%TYPE;
    v_admin_type member_tbl.admin_type%TYPE;
BEGIN
    SELECT member_role, admin_type
      INTO v_role, v_admin_type
      FROM member_tbl
     WHERE member_id = :NEW.member_id;

    IF UPPER(NVL(v_role, '')) <> 'ADMIN'
       OR NVL(v_admin_type, 'X') <> '강사' THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            '시설 담당자는 member_role=ADMIN 이고 admin_type=강사 인 계정만 가능합니다.'
        );
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(
            -20002,
            '시설 담당자(member_id)가 회원 테이블에 존재하지 않습니다.'
        );
END;
/
-- ✅ 결과: 관리자(ADMIN)+강사 계정만 시설 담당자로 지정 가능

--------------------------------------------------------------------------------
-- 4) 트리거 #2 : 수정일 자동 관리
--------------------------------------------------------------------------------
BEGIN
  EXECUTE IMMEDIATE 'DROP TRIGGER trg_facility_mod_ts';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -4080 THEN RAISE; END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_facility_mod_ts
BEFORE INSERT OR UPDATE ON facility_tbl
FOR EACH ROW
BEGIN
  IF INSERTING THEN
    :NEW.facility_mod_date := NULL;                                  -- 신규 생성 시 수정일은 NULL
    :NEW.facility_reg_date := NVL(:NEW.facility_reg_date, SYSDATE);  -- 등록일 기본값 보정
  ELSIF UPDATING THEN
    :NEW.facility_mod_date := SYSDATE;                               -- 실제 수정 시각 자동 기록
  END IF;
END;
/
-- ✅ 결과: 수정하지 않았는데 수정일이 들어가는 문제 방지

--------------------------------------------------------------------------------
-- 5) 더미 데이터 준비 (재실행 대비 삭제 후 삽입)
--------------------------------------------------------------------------------
DELETE FROM facility_tbl WHERE facility_id IN (1, 2);
COMMIT;

-- (1) 축구장
INSERT INTO facility_tbl (
    facility_id, facility_name, member_id, facility_phone,
    facility_content, facility_image_path,
    facility_person_max, facility_person_min,
    facility_use, facility_reg_date,
    facility_open_time, facility_close_time
) VALUES (
    1, '축구장', 'hong9', '031-1111-1111',
    '축구장입니다.', NULL,
    50, 20,
    'Y', SYSDATE,
    TRUNC(SYSDATE) + (8/24),
    TRUNC(SYSDATE) + (22/24)
);

-- (2) 농구장
INSERT INTO facility_tbl (
    facility_id, facility_name, member_id, facility_phone,
    facility_content, facility_image_path,
    facility_person_max, facility_person_min,
    facility_use, facility_reg_date,
    facility_open_time, facility_close_time
) VALUES (
    2, '농구장', 'hong9', '031-2222-2222',
    '농구장입니다.', NULL,
    50, 20,
    'Y', SYSDATE,
    TRUNC(SYSDATE) + (8/24),
    TRUNC(SYSDATE) + (22/24)
);

COMMIT;

--------------------------------------------------------------------------------
-- 6) 트리거 기능 테스트 (권한 검증)
--------------------------------------------------------------------------------
-- 실패 케이스(테스트용) → ORA-20001 발생해야 정상
/*
INSERT INTO facility_tbl (
     facility_id, facility_name, member_id, facility_phone,
     facility_content, facility_image_path,
     facility_person_max, facility_person_min,
     facility_use, facility_reg_date,
     facility_open_time, facility_close_time
 ) VALUES (
     3, '야구장', 'hong1', '031-3333-3333',
     '야구장입니다.', NULL,
     50, 20,
     'Y', SYSDATE,
     TRUNC(SYSDATE) + (8/24),
     TRUNC(SYSDATE) + (22/24)
 );
*/
-- ↑ 강사 권한 없는 user 계정 → 트리거에서 차단됨

--------------------------------------------------------------------------------
-- 7) 확인 조회
--------------------------------------------------------------------------------
SELECT
    facility_id         AS "시설번호",
    facility_name       AS "시설명",
    member_id           AS "강사ID",
    facility_phone      AS "연락처",
    facility_content    AS "시설설명",
    facility_image_path AS "이미지경로",
    facility_person_max AS "최대인원",
    facility_person_min AS "최소인원",
    CASE facility_use WHEN 'Y' THEN '사용' ELSE '미사용' END AS "사용여부",
    TO_CHAR(facility_reg_date, 'YYYY-MM-DD HH24:MI')           AS "등록일",
    NVL(TO_CHAR(facility_mod_date, 'YYYY-MM-DD HH24:MI'), '-') AS "수정일",
    TO_CHAR(facility_open_time, 'HH24:MI')                     AS "운영시작",
    TO_CHAR(facility_close_time, 'HH24:MI')                    AS "운영종료"
FROM facility_tbl
ORDER BY facility_id;

--------------------------------------------------------------------------------
-- 8-1) 💀 데이터 초기화 (안전 모드) 💀
--      - 더미(hong9) 시설만 정리 / 구조·제약 유지
--------------------------------------------------------------------------------

-- 시설ID가 1, 2인 시설의 더미데이터 삭제처리
DELETE FROM facility_tbl WHERE facility_id IN (1,2);
COMMIT;

-- 모두 시설 더미데이터 삭제처리
DELETE FROM facility_tbl;
COMMIT;

--------------------------------------------------------------------------------
-- 8-2) 💀 ddl 블록까지 안전 삭제 💀
--      - 실제 구조 제거 (테스트 종료 시 사용)
--------------------------------------------------------------------------------

BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_facility_insert'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_facility_mod_ts'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE facility_tbl CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
