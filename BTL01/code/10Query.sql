CREATE DATABASE LINK gd1_to_gd2 CONNECT TO GiamDocVirtual IDENTIFIED BY "123456" USING 'hn_link';
CREATE DATABASE LINK gd1_to_gd3 CONNECT TO GiamDocVirtual IDENTIFIED BY "123456" USING 'dn_link';

CREATE DATABASE LINK qlk1_to_qlk2 CONNECT TO QuanLyKhoVirtual IDENTIFIED BY "123456" USING 'hn_link';
CREATE DATABASE LINK qlk1_to_qlk3 CONNECT TO QuanLyKhoVirtual IDENTIFIED BY "123456" USING 'dn_link';

CREATE DATABASE LINK nv1_to_nv2 CONNECT TO NhanVienVirtual IDENTIFIED BY "123456" USING 'hn_link';
CREATE DATABASE LINK nv1_to_nv3 CONNECT TO NhanVienVirtual IDENTIFIED BY "123456" USING 'dn_link';


-- Câu 1
-- Đăng nhập bằng user GiamDoc tại Site 1
WITH ALL_SALES_DETAILS AS (
    -- 1. Lấy dữ liệu tại Chi nhánh 1
    SELECT MASANPHAM, SOLUONG, THANHTIEN, N'Miền Nam' AS VUNG_MIEN
    FROM CN1.CHITIETDONHANG
    UNION ALL
    -- 2. Lấy dữ liệu từ Chi nhánh 2 
    SELECT MASANPHAM, SOLUONG, THANHTIEN, N'Miền Bắc' AS VUNG_MIEN
    FROM CN2.CHITIETDONHANG@GD1_TO_GD2
    UNION ALL
    -- 3. Lấy dữ liệu từ Chi nhánh 3 
    SELECT MASANPHAM, SOLUONG, THANHTIEN, N'Miền Trung' AS VUNG_MIEN
    FROM CN3.CHITIETDONHANG@GD1_TO_GD3
),
PRODUCT_REVENUE AS (
    SELECT 
        asd.MASANPHAM,
        sp.TENSANPHAM,
        dm.TENDANHMUC,
        SUM(asd.SOLUONG) AS TONG_SO_LUONG,
        SUM(asd.THANHTIEN) AS TONG_DOANH_THU
    FROM ALL_SALES_DETAILS asd
    JOIN CN1.SANPHAM sp ON asd.MASANPHAM = sp.MASANPHAM
    JOIN CN1.DANHMUC_SANPHAM dm ON sp.MASANPHAM = dm.MASANPHAM
    GROUP BY asd.MASANPHAM, sp.TENSANPHAM, dm.TENDANHMUC
)
SELECT * FROM (
    SELECT 
        RANK() OVER (ORDER BY TONG_DOANH_THU DESC) AS XEP_HANG_TOAN_QUOC,
        MASANPHAM,
        TENSANPHAM,
        TENDANHMUC,
        TONG_SO_LUONG,
        TO_CHAR(TONG_DOANH_THU, '999,999,999,999') || ' VND' AS DOANH_THU_DINH_DANG
    FROM PRODUCT_REVENUE
) 
WHERE XEP_HANG_TOAN_QUOC <= 10;


-- Câu 2
-- Đăng nhập bằng user GiamDoc tại Site 1
WITH ALL_SALES AS (
    -- 1. Lấy dữ liệu CN1 
    SELECT cdt.MASANPHAM, SUM(cdt.SOLUONG) AS SL_BAN, N'Miền Nam' AS VUNG
    FROM CN1.CHITIETDONHANG cdt
    JOIN CN1.DONHANG dh ON cdt.MADONHANG = dh.MADONHANG
    WHERE dh.NGAYTAO = TO_DATE('2025-04-30', 'YYYY-MM-DD')
    GROUP BY cdt.MASANPHAM
    UNION ALL
    -- 2. Lấy dữ liệu CN2 
    SELECT cdt2.MASANPHAM, SUM(cdt2.SOLUONG), N'Miền Bắc'
    FROM CN2.CHITIETDONHANG@GD1_TO_GD2 cdt2
    JOIN CN2.DONHANG@GD1_TO_GD2 dh2 ON cdt2.MADONHANG = dh2.MADONHANG
    WHERE dh2.NGAYTAO = TO_DATE('2025-04-30', 'YYYY-MM-DD')
    GROUP BY cdt2.MASANPHAM
    UNION ALL
    -- 3. Lấy dữ liệu CN3 
    SELECT cdt3.MASANPHAM, SUM(cdt3.SOLUONG), N'Miền Trung'
    FROM CN3.CHITIETDONHANG@GD1_TO_GD3 cdt3
    JOIN CN3.DONHANG@GD1_TO_GD3 dh3 ON cdt3.MADONHANG = dh3.MADONHANG
    WHERE dh3.NGAYTAO = TO_DATE('2025-04-30', 'YYYY-MM-DD')
    GROUP BY cdt3.MASANPHAM
),
STATS_WITH_AVG AS (
    -- Bước 2: Tính trung bình của từng vùng bằng
    SELECT 
        MASANPHAM, 
        SL_BAN, 
        VUNG,
        AVG(SL_BAN) OVER (PARTITION BY VUNG) AS SL_TRUNG_BINH_VUNG
    FROM ALL_SALES
)
-- Bước 3: Xuất kết quả các sản phẩm của từng vùng
SELECT 
    s.VUNG,
    sp.TENSANPHAM,
    s.SL_BAN,
    ROUND(s.SL_TRUNG_BINH_VUNG, 2) AS TRUNG_BINH_VUNG,
    -- Tính % vượt mức để báo cáo thêm ấn tượng
    ROUND(((s.SL_BAN - s.SL_TRUNG_BINH_VUNG) / s.SL_TRUNG_BINH_VUNG) * 100, 2) || '%' AS TY_LE_VUOT
FROM STATS_WITH_AVG s
JOIN CN1.SANPHAM sp ON s.MASANPHAM = sp.MASANPHAM
WHERE s.SL_BAN > s.SL_TRUNG_BINH_VUNG
ORDER BY s.VUNG, s.SL_BAN DESC;

--Cau3
-- Thực thi tại Site 1 với role NhanVien
WITH GLOBAL_BILL_DETAILS AS (
    -- 1. Lấy mã KH và tổng tiền từ  Chi nhánh 1 
    SELECT MAKHACHHANG, TONGTIEN
    FROM CN1.DONHANG
    UNION ALL
    -- 2. Lấy mã KH và tổng tiền từ Chi nhánh 2 
    SELECT MAKHACHHANG, TONGTIEN
    FROM CN2.DONHANG@NV1_TO_NV2
    UNION ALL
    -- 3. Lấy mã KH và tổng tiền từ Chi nhánh 3 
    SELECT MAKHACHHANG, TONGTIEN
    FROM CN3.DONHANG@NV1_TO_NV3
),
VIP_CUSTOMER_IDS AS (
    -- Bước 2: Gom cụm theo từng khách hàng và lọc những người mua trên 1 tỷ
    SELECT 
        MAKHACHHANG,
        SUM(TONGTIEN) AS TONG_CHI_TIEU
    FROM GLOBAL_BILL_DETAILS
    GROUP BY MAKHACHHANG
    HAVING SUM(TONGTIEN) > 1000000000 -- Điều kiện lọc VIP (> 1000.000.000 VND)
)
-- Bước 3: Join ngược lại bảng KHACHHANG tại Local để lấy thông tin chi tiết liên hệ
SELECT 
    v.MAKHACHHANG,
    kh.HOTEN,
    kh.EMAIL,
    kh.SDT,
    kh.DIACHI,
    TO_CHAR(v.TONG_CHI_TIEU, '999,999,999,999') || ' VND' AS TONG_CHI_TIEU_TOAN_QUOC
FROM VIP_CUSTOMER_IDS v
JOIN CN1.KHACHHANG kh ON v.MAKHACHHANG = kh.MAKHACHHANG -- Bảng nhân bản tại chỗ
ORDER BY v.TONG_CHI_TIEU DESC;

--Cau4
-- Thực thi tại Site 1 với quyền QuanLyKho
WITH ALL_INVENTORY AS (
    -- 1. Lấy tồn kho tại Miền Nam 
    SELECT MASANPHAM, SOLUONG, N'Miền Nam' AS KHU_VUC
    FROM CN1.KHOSANPHAM_QLKHO
    UNION ALL
    -- 2. Lấy tồn kho tại Miền Bắc 
    SELECT MASANPHAM, SOLUONG, N'Miền Bắc'
    FROM CN2.KHOSANPHAM_QLKHO@QLK1_TO_QLK2
    
    UNION ALL
    
    -- 3. Lấy tồn kho tại Miền Trung 
    SELECT MASANPHAM, SOLUONG, N'Miền Trung'
    FROM CN3.KHOSANPHAM_QLKHO@QLK1_TO_QLK3
),
INVENTORY_ANALYTICS AS (
    -- Bước 2: Tính tổng tồn kho toàn quốc cho mỗi SP bằng hàm cửa sổ
    SELECT 
        MASANPHAM,
        KHU_VUC,
        SOLUONG AS TON_TAI_CHO,
        SUM(SOLUONG) OVER (PARTITION BY MASANPHAM) AS TONG_TON_TOAN_QUOC
    FROM ALL_INVENTORY
)
-- Bước 3: Lọc sản phẩm chiếm tỷ trọng >= 50% và Join lấy tên SP
SELECT 
    ia.KHU_VUC,
    ia.MASANPHAM,
    sp.TENSANPHAM,
    ia.TON_TAI_CHO,
    ia.TONG_TON_TOAN_QUOC,
    ROUND((ia.TON_TAI_CHO / NULLIF(ia.TONG_TON_TOAN_QUOC, 0)) * 100, 2) || '%' AS TY_TRONG
FROM INVENTORY_ANALYTICS ia
JOIN CN1.SANPHAM sp ON ia.MASANPHAM = sp.MASANPHAM -- Join bảng nhân bản local
WHERE (ia.TON_TAI_CHO / NULLIF(ia.TONG_TON_TOAN_QUOC, 0)) >= 0.5
  AND ia.TONG_TON_TOAN_QUOC > 0 -- Tránh chia cho 0 và bỏ qua hàng không còn tồn
ORDER BY ia.MASANPHAM, ia.TON_TAI_CHO DESC;