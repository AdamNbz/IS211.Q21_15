-- 1. Bảng Chi Nhánh (
CREATE TABLE CHINHANH (
    MACHINHANH VARCHAR2(10) PRIMARY KEY,
    TENCHINHANH NVARCHAR2(100) NOT NULL,
    DIACHI NVARCHAR2(200)
);

-- 2. Bảng Khách Hàng 
CREATE TABLE KHACHHANG (
    MAKHACHHANG VARCHAR2(15) PRIMARY KEY,
    EMAIL VARCHAR2(100) UNIQUE NOT NULL,
    HOTEN NVARCHAR2(100) NOT NULL,
    SDT VARCHAR2(15),
    DIACHI NVARCHAR2(200),
    GIOITINH NVARCHAR2(10),
    NGAYSINH DATE,
    NGAYDANGKY DATE DEFAULT SYSDATE
);

-- 3. Bảng Sản Phẩm (Mảnh dọc gốc lưu thông tin thương mại)
CREATE TABLE SANPHAM (
    MASANPHAM VARCHAR2(15) PRIMARY KEY,
    TENSANPHAM NVARCHAR2(150) NOT NULL,
    GIA NUMBER(12, 2) CHECK (GIA >= 0)
);


-- =================================================================
-- TẦNG 2: CÁC BẢNG PHỤ THUỘC TẦNG 1 (CHỨA KHÓA NGOẠI ĐƠN)
-- =================================================================

-- 4. Bảng Nhân Viên (Phụ thuộc CHINHANH)
CREATE TABLE NHANVIEN (
    MANHANVIEN VARCHAR2(15) PRIMARY KEY,
    MACHINHANH VARCHAR2(10),
    HOTEN NVARCHAR2(100) NOT NULL,
    GIOITINH NVARCHAR2(10),
    NGAYSINH DATE,
    SDT VARCHAR2(15),
    DIACHI NVARCHAR2(200),
    NGAYVAOLAM DATE,
    CHUCVU NVARCHAR2(50),
    LUONG NUMBER(10, 2),
    FOREIGN KEY (MACHINHANH) REFERENCES CHINHANH(MACHINHANH)
);

-- 5. Bảng Thuộc Tính Sản Phẩm (Mảnh dọc chi tiết - Phụ thuộc SANPHAM)
CREATE TABLE THUOCTINH_SANPHAM (
    MASANPHAM VARCHAR2(15),
    TENTHUOCTINH NVARCHAR2(100),
    GIATRITHUOCTINH NVARCHAR2(250),
    PRIMARY KEY (MASANPHAM, TENTHUOCTINH),
    FOREIGN KEY (MASANPHAM) REFERENCES SANPHAM(MASANPHAM)
);

-- 6. Bảng Danh Mục Sản Phẩm (Phụ thuộc SANPHAM)
CREATE TABLE DANHMUC_SANPHAM (
    MASANPHAM VARCHAR2(15),
    TENDANHMUC NVARCHAR2(100),
    PRIMARY KEY (MASANPHAM, TENDANHMUC),
    FOREIGN KEY (MASANPHAM) REFERENCES SANPHAM(MASANPHAM)
);




-- 7. Bảng Đơn Hàng (Phụ thuộc KHACHHANG và NHANVIEN)
CREATE TABLE DONHANG (
    MADONHANG VARCHAR2(20) PRIMARY KEY,
    MAKHACHHANG VARCHAR2(15),
    MANHANVIEN VARCHAR2(15),
    TONGTIEN NUMBER(12, 2) CHECK (TONGTIEN >= 0),
    NGAYTAO DATE DEFAULT SYSDATE,
    PHUONGTHUCTHANHTOAN NVARCHAR2(50),
    FOREIGN KEY (MAKHACHHANG) REFERENCES KHACHHANG(MAKHACHHANG),
    FOREIGN KEY (MANHANVIEN) REFERENCES NHANVIEN(MANHANVIEN)
);

-- 8. Bảng Chi Tiết Đơn Hàng (Phụ thuộc DONHANG và SANPHAM)
CREATE TABLE CHITIETDONHANG (
    MADONHANG VARCHAR2(20),
    MASANPHAM VARCHAR2(15),
    SOLUONG NUMBER(6) CHECK (SOLUONG > 0),
    THANHTIEN NUMBER(12, 2) CHECK (THANHTIEN >= 0),
    PRIMARY KEY (MADONHANG, MASANPHAM),
    FOREIGN KEY (MADONHANG) REFERENCES DONHANG(MADONHANG),
    FOREIGN KEY (MASANPHAM) REFERENCES SANPHAM(MASANPHAM)
);

-- 9. Kho Sản Phẩm - Quản Lý Kho (Phụ thuộc SANPHAM và CHINHANH)
CREATE TABLE KHOSANPHAM_QLKHO (
    MASANPHAM VARCHAR2(15),
    MACHINHANH VARCHAR2(10),
    SOLUONG NUMBER(8) CHECK (SOLUONG >= 0),
    NGAYCAPNHAT DATE DEFAULT SYSDATE,
    PRIMARY KEY (MASANPHAM, MACHINHANH),
    FOREIGN KEY (MASANPHAM) REFERENCES SANPHAM(MASANPHAM),
    FOREIGN KEY (MACHINHANH) REFERENCES CHINHANH(MACHINHANH)
);

-- 10. Kho Sản Phẩm - Quản Lý Bán Hàng (Mảnh hỗn hợp - Phụ thuộc SANPHAM và CHINHANH)
CREATE TABLE KHOSANPHAM_QLBANHANG (
    MASANPHAM VARCHAR2(15),
    MACHINHANH VARCHAR2(10),
    TINHTRANG NVARCHAR2(30) CHECK (TINHTRANG IN (N'Còn hàng', N'Tạm hết hàng')),
    NGAYCAPNHAT DATE DEFAULT SYSDATE,
    TONGSLDABAN NUMBER(8) DEFAULT 0,
    TONGSLDANHGIA NUMBER(8) DEFAULT 0,
    DIEMDANHGIA NUMBER(3, 2),
    TILETRAHANG NUMBER(5, 2),
    PRIMARY KEY (MASANPHAM, MACHINHANH),
    FOREIGN KEY (MASANPHAM) REFERENCES SANPHAM(MASANPHAM),
    FOREIGN KEY (MACHINHANH) REFERENCES CHINHANH(MACHINHANH)
);

SET SERVEROUTPUT ON;

DECLARE
    ----------------------------------------------------------------------------
    -- CẤU HÌNH SỐ MÁY TẠI ĐÂY (Thay đổi: 1, 2, hoặc 3 trước khi chạy trên từng máy)
    ----------------------------------------------------------------------------
    v_id_may      NUMBER := 1; 

    v_i           NUMBER;
    v_cust_idx    NUMBER;
    v_emp_idx     NUMBER;
    v_prod_idx    NUMBER;
    v_order_idx   NUMBER; -- Sẽ tự động tính toán theo số máy

    -- Các biến tính toán doanh thu
    v_soluong     NUMBER;
    v_gia_goc     NUMBER;
    v_thanhtien   NUMBER;
    v_tongtien    NUMBER;

    -- Biến lưu tên chuỗi ngẫu nhiên
    v_ten_sp      NVARCHAR2(150);
    v_ho_ten      NVARCHAR2(100);
    v_domain      VARCHAR2(30);
    v_ngay_tao    DATE;
    v_str_ngay    VARCHAR2(6);
    v_ma_cn       VARCHAR2(10);

    -- Các biến phục vụ thuật toán ngẫu nhiên thực tế
    v_items_per_order NUMBER;
    v_rand_rating     NUMBER(3,2);
    v_rand_return     NUMBER(4,3); 

    -- Kiểm soát số lượng (Chính xác 333,364 dòng giao dịch chi tiết cho MỖI MÁY)
    v_total_details_inserted NUMBER := 0;
    v_target_details         NUMBER := 333364; 
    v_batch_size             NUMBER := 50000;

    -- Biến hỗ trợ tránh trùng sản phẩm trong cùng một đơn hàng
    v_rand_base              NUMBER; 
    v_selected_prod_id       NUMBER;

    -- Biến bổ trợ phân loại danh mục thông minh
    v_rand_brand_idx         NUMBER;
    v_rand_type_idx          NUMBER;
    v_rand_color_idx         NUMBER;
    v_curr_p_code            VARCHAR2(15);

    -- Biến lưu dải phân hoạch biên dữ liệu
    v_cust_start             NUMBER;
    v_cust_end               NUMBER;
    v_emp_start              NUMBER;
    v_emp_end                NUMBER;

    -- Mảng danh mục hỗ trợ sinh chuỗi trực quan
    TYPE t_str_array IS TABLE OF NVARCHAR2(50);
    v_brands      t_str_array := t_str_array(N'Apple', N'Samsung', N'Sony', N'Asus', N'Logitech', N'Xiaomi');
    v_prod_types  t_str_array := t_str_array(N'iPhone 15 Pro Max', N'Galaxy S24 Ultra', N'MacBook Air M3', N'Tai nghe WH-1000XM5', N'Chuột không dây MX Master 3S', N'Redmi Note 13');
    v_colors      t_str_array := t_str_array(N'Titan Tự Nhiên', N'Đen Huyền Bí', N'Trắng Bạc', N'Xanh Whale');

    v_first_names t_str_array := t_str_array(N'Nguyễn', N'Trần', N'Lê', N'Phạm', N'Hoàng', N'Phan', N'Vũ');
    v_mid_names   t_str_array := t_str_array(N'Văn', N'Thị', N'Minh', N'Gia', N'Anh', N'Đức', N'Hải');
    v_last_names  t_str_array := t_str_array(N'Bảo', N'An', N'Hùng', N'Tuấn', N'Vy', N'Linh', N'Trang');
BEGIN
    -- TỰ ĐỘNG PHÂN HOẠCH ĐỘC LẬP THEO MÁY
    v_ma_cn      := 'CN' || LPAD(v_id_may, 2, '0');
    v_cust_start := ((v_id_may - 1) * 1200) + 1;
    v_cust_end   := v_id_may * 1200;
    v_emp_start  := ((v_id_may - 1) * 400) + 1;
    v_emp_end    := v_id_may * 400;
    v_order_idx  := ((v_id_may - 1) * 400000) + 1;

    DBMS_OUTPUT.PUT_LINE('--- BẮT ĐẦU KHỞI TẠO DỮ LIỆU PHÂN HOẠCH CHO MÁY: ' || v_id_may || ' (Chi nhánh: ' || v_ma_cn || ') ---');

    -- 1. CHÈN DỮ LIỆU: CHINHANH
    INSERT INTO CHINHANH VALUES (
        v_ma_cn, 
        CASE v_id_may WHEN 1 THEN N'TechMarket - Miền Nam' WHEN 2 THEN N'TechMarket - Miền Bắc' ELSE N'TechMarket - Miền Trung' END,
        CASE v_id_may WHEN 1 THEN N'TPHCM' WHEN 2 THEN N'Hà Nội' ELSE N'Đà Nẵng' END
    );

    -- 2. CHÈN DỮ LIỆU: KHACHHANG (1,200 khách hàng độc nhất cho mỗi máy)
    FOR v_i IN v_cust_start..v_cust_end LOOP
            v_ho_ten := v_first_names(TRUNC(DBMS_RANDOM.VALUE(1, 8))) || ' ' ||
                        v_mid_names(TRUNC(DBMS_RANDOM.VALUE(1, 8))) || ' ' ||
                        v_last_names(TRUNC(DBMS_RANDOM.VALUE(1, 8)));

            v_domain := CASE TRUNC(DBMS_RANDOM.VALUE(0, 3)) WHEN 0 THEN '@gmail.com' WHEN 1 THEN '@yahoo.com' ELSE '@hotmail.com' END;

            INSERT INTO KHACHHANG (MAKHACHHANG, EMAIL, HOTEN, SDT, DIACHI, GIOITINH, NGAYSINH, NGAYDANGKY)
            VALUES (
                       'KH' || LPAD(v_i, 5, '0'),
                       'user' || v_i || v_domain,
                       v_ho_ten,
                       '09' || TRUNC(DBMS_RANDOM.VALUE(10000000, 99999999)),
                       CASE v_id_may WHEN 1 THEN N'Khu vực TPHCM' WHEN 2 THEN N'Khu vực Hà Nội' ELSE N'Khu vực Đà Nẵng' END,
                       CASE WHEN DBMS_RANDOM.VALUE(0, 1) > 0.45 THEN N'Nam' ELSE N'Nữ' END,
                       TO_DATE('1985-01-01', 'YYYY-MM-DD') + TRUNC(DBMS_RANDOM.VALUE(0, 7000)),
                       TO_DATE('2024-01-01', 'YYYY-MM-DD') + TRUNC(DBMS_RANDOM.VALUE(0, 500))
                   );
        END LOOP;

    -- 3. CHÈN DỮ LIỆU: NHANVIEN (400 nhân viên độc nhất cho mỗi máy)
    FOR v_i IN v_emp_start..v_emp_end LOOP
            v_ho_ten := v_first_names(TRUNC(DBMS_RANDOM.VALUE(1, 8))) || ' ' ||
                        v_mid_names(TRUNC(DBMS_RANDOM.VALUE(1, 8))) || ' ' ||
                        v_last_names(TRUNC(DBMS_RANDOM.VALUE(1, 8)));
            INSERT INTO NHANVIEN (MANHANVIEN, MACHINHANH, HOTEN, GIOITINH, NGAYSINH, SDT, DIACHI, NGAYVAOLAM, CHUCVU, LUONG)
            VALUES (
                       'NV' || LPAD(v_i, 5, '0'),
                       v_ma_cn,
                       v_ho_ten,
                       CASE WHEN DBMS_RANDOM.VALUE(0, 1) > 0.5 THEN N'Nam' ELSE N'Nữ' END,
                       TO_DATE('1988-01-01', 'YYYY-MM-DD') + TRUNC(DBMS_RANDOM.VALUE(0, 5000)),
                       '08' || TRUNC(DBMS_RANDOM.VALUE(50000000, 99999999)),
                       CASE v_id_may WHEN 1 THEN N'Nội thành TPHCM' WHEN 2 THEN N'Nội thành Hà Nội' ELSE N'Nội thành Đà Nẵng' END,
                       TO_DATE('2021-01-01', 'YYYY-MM-DD') + TRUNC(DBMS_RANDOM.VALUE(0, 1200)),
                       CASE WHEN v_i <= (v_emp_start + 40) THEN N'Quản lý kho' ELSE N'Nhân viên bán hàng' END,
                       CASE WHEN v_i <= (v_emp_start + 40) THEN 16000000 ELSE 10500000 END
                   );
        END LOOP;

    -- 4. CHÈN DỮ LIỆU: SANPHAM (1,100 dòng dùng chung danh mục mã nhưng lưu kho riêng)
    FOR v_i IN 1..1100 LOOP
            v_curr_p_code := 'SP' || LPAD(v_i, 5, '0');
            
            v_rand_brand_idx := TRUNC(DBMS_RANDOM.VALUE(1, 7)); 
            v_rand_type_idx  := TRUNC(DBMS_RANDOM.VALUE(1, 7)); 
            v_rand_color_idx := TRUNC(DBMS_RANDOM.VALUE(1, 5)); 
            
            v_ten_sp := v_brands(v_rand_brand_idx) || ' ' || v_prod_types(v_rand_type_idx) || ' (' || v_colors(v_rand_color_idx) || ')';

            v_gia_goc := CASE v_rand_type_idx
                             WHEN 1 THEN 29900000 + (MOD(v_i, 5) * 1000000)  
                             WHEN 2 THEN 25900000 + (MOD(v_i, 5) * 800000)   
                             WHEN 3 THEN 21490000 + (MOD(v_i, 4) * 1500000)  
                             WHEN 4 THEN 6890000 + (MOD(v_i, 3) * 300000)    
                             WHEN 5 THEN 2250000 + (MOD(v_i, 10) * 5000)     
                             ELSE 4150000 + (MOD(v_i, 6) * 120000)           
                END;
                
            -- Dùng lệnh MERGE (Upsert) để tránh lỗi trùng lặp khi chạy 3 máy chung 1 cụm
            MERGE INTO SANPHAM t USING (SELECT v_curr_p_code AS masanpham FROM dual) s
            ON (t.MASANPHAM = s.masanpham)
            WHEN NOT MATCHED THEN
                INSERT (MASANPHAM, TENSANPHAM, GIA) VALUES (v_curr_p_code, v_ten_sp, v_gia_goc);

            MERGE INTO DANHMUC_SANPHAM t USING (SELECT v_curr_p_code AS masanpham FROM dual) s
            ON (t.MASANPHAM = s.masanpham)
            WHEN NOT MATCHED THEN
                INSERT VALUES (v_curr_p_code, CASE WHEN v_rand_type_idx IN (1, 2, 6) THEN N'Điện thoại' WHEN v_rand_type_idx = 3 THEN N'Máy tính xách tay' ELSE N'Phụ kiện điện tử' END);

            MERGE INTO THUOCTINH_SANPHAM t USING (SELECT v_curr_p_code AS masanpham, N'Thông số' AS tt FROM dual) s
            ON (t.MASANPHAM = s.masanpham AND t.TENTHUOCTINH = s.tt)
            WHEN NOT MATCHED THEN
                INSERT VALUES (v_curr_p_code, N'Thông số', CASE WHEN v_rand_type_idx IN (1,2,3,6) THEN N'RAM 8GB | SSD 256GB' ELSE N'Bảo hành 12T' END);
        END LOOP;

    -- 6. CHÈN DỮ LIỆU BẢNG KHO (Lưu trữ theo chi nhánh riêng biệt)
    FOR v_i IN 1..1100 LOOP
            v_curr_p_code := 'SP' || LPAD(v_i, 5, '0');
            SELECT GIA INTO v_gia_goc FROM SANPHAM WHERE MASANPHAM = v_curr_p_code;

            IF v_gia_goc >= 20000000 THEN
                v_rand_return := ROUND(DBMS_RANDOM.VALUE(0.010, 0.250), 3); 
            ELSIF v_gia_goc >= 5000000 THEN
                v_rand_return := ROUND(DBMS_RANDOM.VALUE(0.150, 0.550), 3); 
            ELSE
                v_rand_return := ROUND(DBMS_RANDOM.VALUE(0.400, 0.980), 3); 
            END IF;

            IF DBMS_RANDOM.VALUE(0, 1) > 0.08 THEN
                v_rand_rating := ROUND(DBMS_RANDOM.VALUE(4.2, 5.0), 2); 
            ELSE
                v_rand_rating := ROUND(DBMS_RANDOM.VALUE(2.5, 3.9), 2); 
            END IF;

            INSERT INTO KHOSANPHAM_QLKHO VALUES (v_curr_p_code, v_ma_cn, TRUNC(DBMS_RANDOM.VALUE(50, 200)), SYSDATE - TRUNC(DBMS_RANDOM.VALUE(0, 10)));
            INSERT INTO KHOSANPHAM_QLBANHANG VALUES (
                                                        v_curr_p_code, v_ma_cn,
                                                        CASE WHEN DBMS_RANDOM.VALUE(0, 1) > 0.96 THEN N'Tạm hết hàng' ELSE N'Còn hàng' END,
                                                        SYSDATE,
                                                        TRUNC(DBMS_RANDOM.VALUE(100, 5000)),
                                                        TRUNC(DBMS_RANDOM.VALUE(20, 800)),
                                                        v_rand_rating,
                                                        v_rand_return
                                                    );
        END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('--- PHÂN HOẠCH DANH MỤC XONG. ĐANG ĐỔ ĐƠN HÀNG ĐỘC QUYỀN MÁY ' || v_id_may || ' ---');

    -- =================================================================
    -- BƯỚC 7: THUẬT TOÁN SINH ĐƠN HÀNG KHÔNG TRÙNG LẶP LIÊN MÁY
    -- =================================================================
    WHILE v_total_details_inserted < v_target_details LOOP
            -- Giới hạn dải lấy khách hàng và nhân viên chuẩn xác theo máy
            v_cust_idx := TRUNC(DBMS_RANDOM.VALUE(v_cust_start, v_cust_end + 1));
            v_emp_idx  := TRUNC(DBMS_RANDOM.VALUE(v_emp_start + 41, v_emp_end + 1)); 
            v_tongtien := 0;

            v_ngay_tao := TO_DATE('2025-01-01', 'YYYY-MM-DD') + TRUNC(DBMS_RANDOM.VALUE(0, 500));
            v_str_ngay := TO_CHAR(v_ngay_tao, 'YYMMDD');

            v_items_per_order := TRUNC(DBMS_RANDOM.VALUE(1, 5));

            IF (v_total_details_inserted + v_items_per_order) > v_target_details THEN
                v_items_per_order := v_target_details - v_total_details_inserted;
            END IF;

            -- ĐĂC BIỆT: Thêm ký tự phân định Máy (v_id_may) vào mã Đơn hàng để triệt tiêu trùng lặp
            INSERT INTO DONHANG (MADONHANG, MAKHACHHANG, MANHANVIEN, TONGTIEN, NGAYTAO, PHUONGTHUCTHANHTOAN)
            VALUES (
                       'DH' || v_id_may || '-' || v_str_ngay || '-' || LPAD(v_order_idx, 7, '0'),
                       'KH' || LPAD(v_cust_idx, 5, '0'),
                       'NV' || LPAD(v_emp_idx, 5, '0'),
                       0,
                       v_ngay_tao,
                       CASE TRUNC(DBMS_RANDOM.VALUE(0, 3)) WHEN 0 THEN N'Chuyển khoản QR' WHEN 1 THEN N'Ví MoMo' ELSE N'Tiền mặt (COD)' END
                   );

            v_rand_base := TRUNC(DBMS_RANDOM.VALUE(1, 1000));

            FOR v_prod_idx IN 1..v_items_per_order LOOP
                    v_selected_prod_id := v_rand_base + v_prod_idx; 
                    v_soluong := CASE WHEN DBMS_RANDOM.VALUE(0, 1) > 0.88 THEN 2 ELSE 1 END;

                    v_rand_type_idx := MOD(v_selected_prod_id, 6) + 1;
                    v_gia_goc := CASE v_rand_type_idx
                                     WHEN 1 THEN 29900000 + (MOD(v_selected_prod_id, 5) * 1000000)
                                     WHEN 2 THEN 25900000 + (MOD(v_selected_prod_id, 5) * 800000)
                                     WHEN 3 THEN 21490000 + (MOD(v_selected_prod_id, 4) * 1500000)
                                     WHEN 4 THEN 6890000 + (MOD(v_selected_prod_id, 3) * 300000)
                                     WHEN 5 THEN 2250000 + (MOD(v_selected_prod_id, 10) * 5000)
                                     ELSE 4150000 + (MOD(v_selected_prod_id, 6) * 120000)
                        END;

                    v_thanhtien := v_soluong * v_gia_goc;
                    v_tongtien  := v_tongtien + v_thanhtien;

                    INSERT INTO CHITIETDONHANG (MADONHANG, MASANPHAM, SOLUONG, THANHTIEN)
                    VALUES (
                               'DH' || v_id_may || '-' || v_str_ngay || '-' || LPAD(v_order_idx, 7, '0'),
                               'SP' || LPAD(v_selected_prod_id, 5, '0'),
                               v_soluong,
                               v_thanhtien
                           );

                    v_total_details_inserted := v_total_details_inserted + 1;
                END LOOP;

            UPDATE DONHANG
            SET TONGTIEN = v_tongtien
            WHERE MADONHANG = 'DH' || v_id_may || '-' || v_str_ngay || '-' || LPAD(v_order_idx, 7, '0');

            v_order_idx := v_order_idx + 1;

            IF MOD(v_total_details_inserted, v_batch_size) = 0 THEN
                COMMIT;
                DBMS_OUTPUT.PUT_LINE('>> Máy ' || v_id_may || ' đã nạp an toàn: ' || v_total_details_inserted || ' dòng...');
            END IF;

        END LOOP;

    COMMIT; 
    DBMS_OUTPUT.PUT_LINE('--- MÁY ' || v_id_may || ' HOÀN THÀNH XUẤT SẮC ---');
    DBMS_OUTPUT.PUT_LINE('TỔNG SỐ DÒNG CHI TIẾT ĐƠN HÀNG ĐÃ NẠP: ' || v_total_details_inserted);
END;
/


Select * From ChiNhanh;
Select * From KhachHang;
Select * From NhanVien;
Select * From SanPham;
Select * From DanhMuc_SanPham;
Select * From THUOCTINH_SanPham;
Select * From DonHang;
Select * From ChiTietDonHang;
Select * From Khosanpham_QLKho;
Select * From Khosanpham_QLBanHang;


-- Tầng 3: Xóa các bảng giao dịch và logistics chứa nhiều khóa ngoại trước
DROP TABLE CHITIETDONHANG CASCADE CONSTRAINTS;
DROP TABLE DONHANG CASCADE CONSTRAINTS;
DROP TABLE KHOSANPHAM_QLKHO CASCADE CONSTRAINTS;
DROP TABLE KHOSANPHAM_QLBANHANG CASCADE CONSTRAINTS;

-- Tầng 2: Xóa các bảng phụ thuộc chứa một khóa ngoại
DROP TABLE NHANVIEN CASCADE CONSTRAINTS;
DROP TABLE THUOCTINH_SANPHAM CASCADE CONSTRAINTS;
DROP TABLE DANHMUC_SANPHAM CASCADE CONSTRAINTS;

-- Tầng 1: Xóa các bảng danh mục gốc độc lập cuối cùng
DROP TABLE CHINHANH CASCADE CONSTRAINTS;
DROP TABLE KHACHHANG CASCADE CONSTRAINTS;
DROP TABLE SANPHAM CASCADE CONSTRAINTS;


