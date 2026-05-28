--Fucntion
CREATE OR REPLACE FUNCTION CN1.F_TINH_TY_LE_DOANH_THU_SP (
    p_MaSanPham IN VARCHAR2
) RETURN NUMBER 
IS
    v_CheckExists   NUMBER := 0;
    v_DoanhThuLocal NUMBER := 0;
    v_DoanhThuBac   NUMBER := 0;
    v_DoanhThuTrung NUMBER := 0;
    v_TongDoanhThu  NUMBER := 0;
    v_TyLe          NUMBER := 0;
    v_TongHeThong   NUMBER := 0;
BEGIN
    -- 1. KIỂM TRA MÃ SẢN PHẨM CÓ TỒN TẠI TRONG DANH MỤC KHÔNG
    -- Sử dụng bảng nhân bản SANPHAM tại Site 1 để kiểm tra nhanh
    SELECT COUNT(*) INTO v_CheckExists 
    FROM CN1.SANPHAM 
    WHERE MASANPHAM = p_MaSanPham;

    IF v_CheckExists = 0 THEN
        -- Nếu không tìm thấy mã SP, ném lỗi ra cho người dùng
        RAISE_APPLICATION_ERROR(-20006, 'Lỗi: Mã sản phẩm ' || p_MaSanPham || ' không tồn tại trong hệ thống!');
    END IF;

    -- 2. TÍNH DOANH THU TỪNG MIỀN
    -- Tại Chi nhánh 1 (Local)
    SELECT NVL(SUM(THANHTIEN), 0) INTO v_DoanhThuLocal
    FROM CN1.CHITIETDONHANG
    WHERE MASANPHAM = p_MaSanPham;

    -- Tại Chi nhánh 2 (Qua DB Link)
    BEGIN
        SELECT NVL(SUM(THANHTIEN), 0) INTO v_DoanhThuBac
        FROM CN2.CHITIETDONHANG@GD1_TO_GD2
        WHERE MASANPHAM = p_MaSanPham;
    EXCEPTION WHEN OTHERS THEN v_DoanhThuBac := 0;
    END;

    -- Tại Chi nhánh 3 (Qua DB Link)
    BEGIN
        SELECT NVL(SUM(THANHTIEN), 0) INTO v_DoanhThuTrung
        FROM CN3.CHITIETDONHANG@GD1_TO_GD3
        WHERE MASANPHAM = p_MaSanPham;
    EXCEPTION WHEN OTHERS THEN v_DoanhThuTrung := 0;
    END;

    -- 3. TỔNG HỢP VÀ TÍNH TOÁN
    v_TongDoanhThu := v_DoanhThuLocal + v_DoanhThuBac + v_DoanhThuTrung;

    -- Tính mẫu số: Tổng doanh thu toàn hệ thống
    SELECT 
        (SELECT NVL(SUM(THANHTIEN), 0) FROM CN1.CHITIETDONHANG) +
        (SELECT NVL(SUM(THANHTIEN), 0) FROM CN2.CHITIETDONHANG@GD1_TO_GD2) +
        (SELECT NVL(SUM(THANHTIEN), 0) FROM CN3.CHITIETDONHANG@GD1_TO_GD3)
    INTO v_TongHeThong FROM DUAL;

    -- 4. TRẢ VỀ KẾT QUẢ
    IF v_TongHeThong > 0 THEN
        v_TyLe := ROUND((v_TongDoanhThu / v_TongHeThong) * 100, 2);
    ELSE
        v_TyLe := 0;
    END IF;

    RETURN v_TyLe;
END;
/


CREATE OR REPLACE PROCEDURE CN1.P_DIEU_CHUYEN_CHUC_VU (
    p_MaNV         IN VARCHAR2,
    p_ChucVu_Moi   IN VARCHAR2
)
IS
    v_SiteHienTai NUMBER := 0;
    v_HoTen       VARCHAR2(100);
BEGIN
    -- SITE 1
    BEGIN
        SELECT HOTEN
        INTO v_HoTen
        FROM CN1.NHANVIEN
        WHERE MANHANVIEN = p_MaNV;

        v_SiteHienTai := 1;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;
    END;

    -- SITE 2
    IF v_SiteHienTai = 0 THEN
        BEGIN
            SELECT HOTEN
            INTO v_HoTen
            FROM CN2.NHANVIEN@GD1_TO_GD2
            WHERE MANHANVIEN = p_MaNV;

            v_SiteHienTai := 2;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;
    END IF;

    -- SITE 3
    IF v_SiteHienTai = 0 THEN
        BEGIN
            SELECT HOTEN
            INTO v_HoTen
            FROM CN3.NHANVIEN@GD1_TO_GD3
            WHERE MANHANVIEN = p_MaNV;

            v_SiteHienTai := 3;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;
    END IF;
    IF v_SiteHienTai = 0 THEN
        RAISE_APPLICATION_ERROR(
            -20005,
            'Không tìm thấy nhân viên: ' || p_MaNV
        );
    END IF;
    IF v_SiteHienTai = 1 THEN
        UPDATE CN1.NHANVIEN
        SET CHUCVU = p_ChucVu_Moi
        WHERE MANHANVIEN = p_MaNV;
    ELSIF v_SiteHienTai = 2 THEN
        UPDATE CN2.NHANVIEN@GD1_TO_GD2
        SET CHUCVU = p_ChucVu_Moi
        WHERE MANHANVIEN = p_MaNV;
    ELSIF v_SiteHienTai = 3 THEN
        UPDATE CN3.NHANVIEN@GD1_TO_GD3
        SET CHUCVU = p_ChucVu_Moi
        WHERE MANHANVIEN = p_MaNV;
    END IF;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE(
        'Đã cập nhật chức vụ cho nhân viên '
        || v_HoTen
        || ' thành '
        || p_ChucVu_Moi
    );
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;

        RAISE_APPLICATION_ERROR(
            -20999,
            'Lỗi hệ thống: ' || SQLERRM
        );
END;

SELECT MANHANVIEN, HOTEN, CHUCVU FROM CN2.NHANVIEN@GD1_TO_GD2 WHere MANHANVIEN = 'NV00453';


EXEC CN1.P_DIEU_CHUYEN_CHUC_VU('KH94232', N'Nhân viên');

SELECT CN1.F_TINH_TY_LE_DOANH_THU_SP('SP00236') AS TYLE
FROM DUAL;

SELECT MANHANVIEN, HOTEN, CHUCVU FROM CN3.NHANVIEN@GD1_TO_GD3 Where MANHANVIEN = 'NV00911';

CREATE OR REPLACE TRIGGER CN1.TRG_DISTRIBUTED_INVENTORY_SYNC
FOR INSERT OR UPDATE ON CN1.CHITIETDONHANG
COMPOUND TRIGGER
    -- Khai báo biến dùng chung
    v_ChenhLech NUMBER;
    v_TonKho     NUMBER;
    -- BƯỚC 1: KIỂM TRA TRƯỚC KHI GHI (BEFORE EACH ROW)
    BEFORE EACH ROW IS
    BEGIN
        -- Tính toán lượng thay đổi số lượng sản phẩm
        IF INSERTING THEN
            v_ChenhLech := :NEW.SOLUONG;
        ELSE
            v_ChenhLech := :NEW.SOLUONG - :OLD.SOLUONG;
        END IF;

        -- Lấy số lượng tồn kho hiện tại (Lưu ý: Phải đúng mã chi nhánh, giả sử Site 1 là 'CN01')
        -- Nếu bạn có nhiều chi nhánh trong cùng 1 bảng, cần join hoặc xác định MACHINHANH
        BEGIN
            SELECT SOLUONG INTO v_TonKho
            FROM CN1.KHOSANPHAM_QLKHO
            WHERE MASANPHAM = :NEW.MASANPHAM
              AND MACHINHANH = 'CN01'; -- Thay 'CN01' bằng mã tương ứng của Site 1
        EXCEPTION 
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20101, 'LỖI: Sản phẩm ' || :NEW.MASANPHAM || ' không có trong kho chi nhánh!');
        END;

        IF v_TonKho < v_ChenhLech THEN
            RAISE_APPLICATION_ERROR(-20102, 'LỖI: Kho không đủ hàng. Hiện có: ' || v_TonKho || ', yêu cầu thêm: ' || v_ChenhLech);
        END IF;
    END BEFORE EACH ROW;

    -- BƯỚC 2: CẬP NHẬT ĐỒNG BỘ SAU KHI GHI (AFTER EACH ROW)
    AFTER EACH ROW IS
    BEGIN
        -- 2.1 Cập nhật bảng Quản lý Kho (Trừ tồn kho)
        UPDATE CN1.KHOSANPHAM_QLKHO
        SET SOLUONG = SOLUONG - v_ChenhLech,
            NGAYCAPNHAT = SYSDATE
        WHERE MASANPHAM = :NEW.MASANPHAM 
          AND MACHINHANH = 'CN01';

        -- 2.2 Cập nhật bảng Quản lý Bán hàng (Cộng dồn TONGSLDABAN)
        UPDATE CN1.KHOSANPHAM_QLBANHANG
        SET TONGSLDABAN = NVL(TONGSLDABAN, 0) + v_ChenhLech,
            NGAYCAPNHAT = SYSDATE
        WHERE MASANPHAM = :NEW.MASANPHAM
          AND MACHINHANH = 'CN01';
    END AFTER EACH ROW;

END;



SELECT SOLUONG FROM CN1.KHOSANPHAM_QLKHO WHERE MASANPHAM = 'SP00236';
SELECT TONGSLDABAN FROM CN1.KHOSANPHAM_QLBANHANG WHERE MASANPHAM = 'SP00236';


--TestCase1
INSERT INTO CN1.CHITIETDONHANG (MADONHANG, MASANPHAM, SOLUONG, THANHTIEN) 
VALUES ('DH1-250808-0000291', 'SP00236', 5, 500000);
SELECT SOLUONG FROM CN1.KHOSANPHAM_QLKHO WHERE MASANPHAM = 'SP00236';
SELECT TONGSLDABAN FROM CN1.KHOSANPHAM_QLBANHANG WHERE MASANPHAM = 'SP00236';
--TestCase2
UPDATE CN1.CHITIETDONHANG 
SET SOLUONG = 15 
WHERE MADONHANG = 'DH1-250808-0000291' AND MASANPHAM = 'SP00236';
SELECT SOLUONG FROM CN1.KHOSANPHAM_QLKHO WHERE MASANPHAM = 'SP00236';
SELECT TONGSLDABAN FROM CN1.KHOSANPHAM_QLBANHANG WHERE MASANPHAM = 'SP00236';
--TestCase3
UPDATE CN1.CHITIETDONHANG 
SET SOLUONG = 5 
WHERE MADONHANG = 'DH1-250808-0000291' AND MASANPHAM = 'SP00236';
SELECT SOLUONG FROM CN1.KHOSANPHAM_QLKHO WHERE MASANPHAM = 'SP00236';
SELECT TONGSLDABAN FROM CN1.KHOSANPHAM_QLBANHANG WHERE MASANPHAM = 'SP00236';
--TestCase3
INSERT INTO CN1.CHITIETDONHANG (MADONHANG, MASANPHAM, SOLUONG, THANHTIEN) 
VALUES ('DH1-250808-0000291', 'SP00236', 200, 50000000);
SELECT SOLUONG FROM CN1.KHOSANPHAM_QLKHO WHERE MASANPHAM = 'SP00236';
SELECT TONGSLDABAN FROM CN1.KHOSANPHAM_QLBANHANG WHERE MASANPHAM = 'SP00236';

ROLLBACK;