/* =====================================================================
   File   : 08_Report.sql
   Noi dung: Cac VIEW lam nguon du lieu cho REPORT (Power BI / Tableau /
             Web demo). Moi view tuong ung 1 report.
   ===================================================================== */

USE QUANLYTHUVIEN
GO

/* ---------------------------------------------------------------------
   REPORT 1. Tinh trang kho sach theo dau sach
   (Bang so lieu + bieu do cot chong: Co san / Dang muon / Hu hong / Mat)
   --------------------------------------------------------------------- */
CREATE VIEW VW_BC_TINHTRANGKHO
AS
SELECT	ROW_NUMBER() OVER (ORDER BY TL.TENTL, DS.TENDS) AS STT,
		DS.MADS, DS.TENDS, TL.TENTL,
		COUNT(CS.MACS) AS TONGSO,
		SUM(CASE WHEN CS.TINHTRANG = N'Có sẵn'		THEN 1 ELSE 0 END) AS COSAN,
		SUM(CASE WHEN CS.TINHTRANG = N'Đang mượn'	THEN 1 ELSE 0 END) AS DANGMUON,
		SUM(CASE WHEN CS.TINHTRANG = N'Hư hỏng'		THEN 1 ELSE 0 END) AS HUHONG,
		SUM(CASE WHEN CS.TINHTRANG = N'Mất'			THEN 1 ELSE 0 END) AS MAT
FROM DAUSACH DS
	JOIN THELOAI TL ON DS.MATL = TL.MATL
	LEFT JOIN CUONSACH CS ON DS.MADS = CS.MADS
GROUP BY DS.MADS, DS.TENDS, TL.TENTL
GO

/* ---------------------------------------------------------------------
   REPORT 2. Xep hang dau sach duoc muon nhieu nhat
   (Bieu do cot ngang top sach)
   --------------------------------------------------------------------- */
CREATE VIEW VW_BC_SACHMUONNHIEU
AS
SELECT	RANK() OVER (ORDER BY COUNT(CT.MAPM) DESC) AS HANG,
		DS.MADS, DS.TENDS, TL.TENTL,
		COUNT(CT.MAPM) AS SOLUOTMUON,
		COUNT(DISTINCT PM.MADG) AS SODOCGIA
FROM DAUSACH DS
	JOIN THELOAI TL ON DS.MATL = TL.MATL
	LEFT JOIN CUONSACH CS ON DS.MADS = CS.MADS
	LEFT JOIN CTPHIEUMUON CT ON CS.MACS = CT.MACS
	LEFT JOIN PHIEUMUON PM ON CT.MAPM = PM.MAPM
GROUP BY DS.MADS, DS.TENDS, TL.TENTL
GO

/* ---------------------------------------------------------------------
   REPORT 3. Luot muon theo thang va the loai
   (Bieu do duong: truc X = thang, truc Y = so luot, moi duong = 1 the loai)
   --------------------------------------------------------------------- */
CREATE VIEW VW_BC_LUOTMUON_THANG
AS
SELECT	YEAR(PM.NGAYMUON) AS NAM,
		MONTH(PM.NGAYMUON) AS THANG,
		TL.TENTL,
		COUNT(*) AS SOLUOTMUON
FROM CTPHIEUMUON CT
	JOIN PHIEUMUON PM ON CT.MAPM = PM.MAPM
	JOIN CUONSACH CS ON CT.MACS = CS.MACS
	JOIN DAUSACH DS ON CS.MADS = DS.MADS
	JOIN THELOAI TL ON DS.MATL = TL.MATL
GROUP BY YEAR(PM.NGAYMUON), MONTH(PM.NGAYMUON), TL.TENTL
GO

/* ---------------------------------------------------------------------
   REPORT 4. Tien phat theo thang va ly do
   (Bieu do tron ty le ly do phat + bang tong hop da thu / chua thu)
   --------------------------------------------------------------------- */
CREATE VIEW VW_BC_TIENPHAT_THANG
AS
SELECT	YEAR(NGAYLAP) AS NAM,
		MONTH(NGAYLAP) AS THANG,
		LYDO,
		COUNT(*) AS SOPHIEU,
		SUM(SOTIEN) AS TONGTIEN,
		SUM(CASE WHEN DATHANHTOAN = 1 THEN SOTIEN ELSE 0 END) AS DATHU,
		SUM(CASE WHEN DATHANHTOAN = 0 THEN SOTIEN ELSE 0 END) AS CHUATHU
FROM PHIEUPHAT
GROUP BY YEAR(NGAYLAP), MONTH(NGAYLAP), LYDO
GO

/* ---------------------------------------------------------------------
   REPORT 5. Danh sach doc gia dang giu sach qua han (tinh den hom nay)
   (Bang canh bao, sap xep theo so ngay tre giam dan)
   --------------------------------------------------------------------- */
CREATE VIEW VW_BC_DOCGIA_QUAHAN
AS
SELECT	ROW_NUMBER() OVER (ORDER BY DATEDIFF(DAY, PM.HANTRA, GETDATE()) DESC, DG.MADG) AS STT,
		DG.MADG, DG.HOTEN, LDG.TENLDG, DG.SODT,
		PM.MAPM, DS.TENDS, PM.NGAYMUON, PM.HANTRA,
		DATEDIFF(DAY, PM.HANTRA, GETDATE()) AS SONGAYTRE,
		dbo.FN_TIENPHATTRE(PM.HANTRA, CAST(GETDATE() AS DATE)) AS TIENPHATTAMTINH
FROM CTPHIEUMUON CT
	JOIN PHIEUMUON PM ON CT.MAPM = PM.MAPM
	JOIN DOCGIA DG ON PM.MADG = DG.MADG
	JOIN LOAIDOCGIA LDG ON DG.MALDG = LDG.MALDG
	JOIN CUONSACH CS ON CT.MACS = CS.MACS
	JOIN DAUSACH DS ON CS.MADS = DS.MADS
WHERE CT.NGAYTRA IS NULL AND PM.HANTRA < CAST(GETDATE() AS DATE)
GO

/* ---------------------------------------------------------------------
   REPORT 6. Hieu suat nhan vien: so phieu muon va so sach da xu ly
   theo thang cua tung thu thu
   --------------------------------------------------------------------- */
CREATE VIEW VW_BC_HIEUSUAT_NHANVIEN
AS
SELECT	NV.MANV, NV.HOTEN,
		YEAR(PM.NGAYMUON) AS NAM,
		MONTH(PM.NGAYMUON) AS THANG,
		COUNT(DISTINCT PM.MAPM) AS SOPHIEU,
		COUNT(CT.MACS) AS SOSACH
FROM NHANVIEN NV
	JOIN PHIEUMUON PM ON NV.MANV = PM.MANV
	JOIN CTPHIEUMUON CT ON PM.MAPM = CT.MAPM
GROUP BY NV.MANV, NV.HOTEN, YEAR(PM.NGAYMUON), MONTH(PM.NGAYMUON)
GO

GRANT SELECT ON VW_BC_TINHTRANGKHO		TO R_QUANLY, R_THUTHU
GRANT SELECT ON VW_BC_SACHMUONNHIEU		TO R_QUANLY, R_THUTHU, R_DOCGIA
GRANT SELECT ON VW_BC_LUOTMUON_THANG	TO R_QUANLY, R_THUTHU
GRANT SELECT ON VW_BC_TIENPHAT_THANG	TO R_QUANLY
GRANT SELECT ON VW_BC_DOCGIA_QUAHAN		TO R_QUANLY, R_THUTHU
GRANT SELECT ON VW_BC_HIEUSUAT_NHANVIEN	TO R_QUANLY
GO

/* ---------------------- VI DU SU DUNG ------------------------------
SELECT * FROM VW_BC_TINHTRANGKHO ORDER BY STT
SELECT * FROM VW_BC_SACHMUONNHIEU ORDER BY HANG
SELECT * FROM VW_BC_LUOTMUON_THANG ORDER BY NAM, THANG, TENTL
SELECT * FROM VW_BC_TIENPHAT_THANG ORDER BY NAM, THANG, LYDO
SELECT * FROM VW_BC_DOCGIA_QUAHAN ORDER BY STT
SELECT * FROM VW_BC_HIEUSUAT_NHANVIEN ORDER BY NAM, THANG, MANV
--------------------------------------------------------------------- */
