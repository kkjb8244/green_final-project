-- =========================================================
-- 🔧 공통: 스키마 고정 (DDL에 스키마 접두어 없음)
-- =========================================================
-- ALTER SESSION SET CURRENT_SCHEMA = gym;

--------------------------------------------------------------------------------
-- 0) 재실행 안전 드롭
--------------------------------------------------------------------------------
BEGIN
  EXECUTE IMMEDIATE 'DROP TRIGGER trg_resv_block_closed_day';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -4080 THEN RAISE; END IF;   -- ORA-04080: 트리거 없음 → 무시
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE reservation_tbl CASCADE CONSTRAINTS';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

--------------------------------------------------------------------------------
-- 1) 예약신청 테이블 생성 (엑셀 사양 1:1)
--------------------------------------------------------------------------------
CREATE TABLE reservation_tbl (
    resv_id           NUMBER         NOT NULL,                 -- 예약 고유 번호 (PK, 결제 연동)
    member_id         VARCHAR2(20)   NOT NULL,                 -- 신청자 ID (FK → member_tbl)
    facility_id       NUMBER         NOT NULL,                 -- 예약 대상 시설 고유번호 (FK → facility_tbl)
    resv_content      VARCHAR2(500),                           -- 신청시 요구 사항(단순 텍스트)
    want_date         DATE           NOT NULL,                 -- 예약 희망일
    resv_date         DATE           DEFAULT SYSDATE,          -- 예약 신청일(프론트 표기용)
    resv_log_time     DATE           DEFAULT SYSDATE,          -- 로그 추적용(log4j2)
    resv_person_count NUMBER,                                   -- 신청 인원 수
    resv_status       VARCHAR2(20)   DEFAULT '완료'            -- 예약 상태(완료/취소/대기)
);

-- 📌 주석
COMMENT ON TABLE  reservation_tbl                    IS '신청(예약)정보';
COMMENT ON COLUMN reservation_tbl.resv_id            IS '예약 고유 번호(결제 시스템과 연동)';
COMMENT ON COLUMN reservation_tbl.member_id          IS '신청자 ID';
COMMENT ON COLUMN reservation_tbl.facility_id        IS '예약 대상 시설 고유번호';
COMMENT ON COLUMN reservation_tbl.resv_content       IS '신청시 요구 사항(단순 텍스트)';
COMMENT ON COLUMN reservation_tbl.want_date          IS '예약 희망일';
COMMENT ON COLUMN reservation_tbl.resv_date          IS '예약 신청일(기본값 SYSDATE; 프론트 표시용)';
COMMENT ON COLUMN reservation_tbl.resv_log_time      IS '신청 로그 시각(기본값 SYSDATE)';
COMMENT ON COLUMN reservation_tbl.resv_person_count  IS '신청 인원 수';
COMMENT ON COLUMN reservation_tbl.resv_status        IS '예약 상태(완료/취소/대기; 기본값 완료)';

--------------------------------------------------------------------------------
-- 2) 제약조건/FK/검증
--------------------------------------------------------------------------------
ALTER TABLE reservation_tbl
  ADD CONSTRAINT reservation_tbl_pk PRIMARY KEY (resv_id);               -- PK

ALTER TABLE reservation_tbl
  ADD CONSTRAINT resv_status_CH CHECK (resv_status IN ('완료','취소','대기')); -- 상태값 검증

ALTER TABLE reservation_tbl
  ADD CONSTRAINT fk_resv_member   FOREIGN KEY (member_id)  REFERENCES member_tbl(member_id);
ALTER TABLE reservation_tbl
  ADD CONSTRAINT fk_resv_facility FOREIGN KEY (facility_id) REFERENCES facility_tbl(facility_id);

-- (권장) 조회 성능 인덱스
CREATE INDEX idx_resv_facility_date ON reservation_tbl (facility_id, want_date);

--------------------------------------------------------------------------------
-- 3) 트리거: 휴무일(closed_day_tbl)인 경우 예약 차단
--    - 엑셀 표에는 FK 연계가 없고, “휴무일에 예약 불가”는 금지 규칙이므로 트리거로 강제
--    - 공휴일 DB 연계는 백엔드에서 처리(DDL은 스키마 정의만 수행)
--------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_resv_block_closed_day
BEFORE INSERT OR UPDATE OF facility_id, want_date ON reservation_tbl
FOR EACH ROW
DECLARE
  v_cnt NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO v_cnt
    FROM closed_day_tbl c
   WHERE c.facility_id = :NEW.facility_id
     AND c.closed_date = :NEW.want_date;

  IF v_cnt > 0 THEN
    RAISE_APPLICATION_ERROR(-20061, '해당 일자는 시설 휴무일이므로 예약할 수 없습니다.');
  END IF;
END;
/
-- ✅ 비고: 공휴일 API/DB는 백엔드에서 holiday_tbl에 적재 후, 필요 시 여기서도 차단 로직 추가

--------------------------------------------------------------------------------
-- 4) 더미데이터 (휴무일과 충돌하지 않도록 날짜 선택)
--    ※ member_tbl: 'hong1','hong2','hong3' 존재
--    ※ facility_tbl: 1(축구장), 2(농구장) 존재
--------------------------------------------------------------------------------
DELETE FROM reservation_tbl WHERE resv_id IN (1,2,3);
COMMIT;

INSERT INTO reservation_tbl (
  resv_id, member_id, facility_id, resv_content, want_date,
  resv_date, resv_log_time, resv_person_count, resv_status
) VALUES (
  1, 'hong1', 1, '골대 추가 요청', TRUNC(SYSDATE)+5,
  SYSDATE, SYSDATE, 10, '완료'
);

INSERT INTO reservation_tbl (
  resv_id, member_id, facility_id, resv_content, want_date,
  resv_date, resv_log_time, resv_person_count, resv_status
) VALUES (
  2, 'hong2', 2, '조명 점검 요청', TRUNC(SYSDATE)+8,
  SYSDATE, SYSDATE, 8, '대기'
);

INSERT INTO reservation_tbl (
  resv_id, member_id, facility_id, resv_content, want_date,
  resv_date, resv_log_time, resv_person_count, resv_status
) VALUES (
  3, 'hong3', 1, '라인 테이프 요청', TRUNC(SYSDATE)+9,
  SYSDATE, SYSDATE, 12, '취소'
);

COMMIT;

--------------------------------------------------------------------------------
-- 5) 확인 조회
--------------------------------------------------------------------------------
/* 예약 + 신청자명 + 시설명 */
SELECT
    r.resv_id                                AS "예약ID",
    r.member_id                              AS "신청자ID",
    m.member_name                            AS "신청자명",
    r.facility_id                            AS "시설ID",
    f.facility_name                          AS "시설명",
    NVL(r.resv_content, '-')                 AS "요구사항",
    TO_CHAR(r.want_date,     'YYYY-MM-DD')   AS "희망일",
    TO_CHAR(r.resv_date,     'YYYY-MM-DD HH24:MI') AS "신청일",
    TO_CHAR(r.resv_log_time, 'YYYY-MM-DD HH24:MI') AS "로그시각",
    r.resv_person_count                      AS "인원",
    r.resv_status                            AS "상태"
FROM reservation_tbl r
JOIN facility_tbl   f ON f.facility_id = r.facility_id
JOIN member_tbl     m ON m.member_id   = r.member_id
ORDER BY r.resv_id;

--------------------------------------------------------------------------------
-- 6-1) 💀 데이터 초기화 (안전 모드) 💀
--      - 예제 더미(resv_id 1~3)만 정리 / 구조·제약 유지
--------------------------------------------------------------------------------
DELETE FROM reservation_tbl WHERE resv_id IN (1,2,3);
COMMIT;

--------------------------------------------------------------------------------
-- 6-2) 💀 ddl 블록까지 안전 삭제 💀
--      - 실제 구조 제거 (테스트 종료 시 사용)
--------------------------------------------------------------------------------
/*
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_resv_block_closed_day';           EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP INDEX idx_resv_facility_date';                EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE reservation_tbl CASCADE CONSTRAINTS';   EXCEPTION WHEN OTHERS THEN NULL; END;
/
*/
