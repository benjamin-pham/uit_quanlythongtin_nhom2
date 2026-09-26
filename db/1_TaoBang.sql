/* =====================================================================
   DO AN MON HOC IE103 - QUAN LY THONG TIN
   De tai : QUAN LY THU VIEN
   File   : 01_TaoBang.sql
   Noi dung: Tao CSDL, tao bang, khoa chinh, khoa ngoai, rang buoc
   ===================================================================== */

USE master
GO

IF DB_ID('QUANLYTHUVIEN') IS NOT NULL
BEGIN
	ALTER DATABASE QUANLYTHUVIEN SET SINGLE_USER WITH ROLLBACK IMMEDIATE
	DROP DATABASE QUANLYTHUVIEN
END
GO

CREATE DATABASE QUANLYTHUVIEN COLLATE Vietnamese_CI_AS
GO

USE QUANLYTHUVIEN
GO

/* ---------------------------------------------------------------------
   1. THELOAI(MATL, TENTL)
   --------------------------------------------------------------------- */
CREATE TABLE THELOAI
(
	MATL	CHAR(4)			PRIMARY KEY,
	TENTL	NVARCHAR(50)	NOT NULL UNIQUE
)

/* ---------------------------------------------------------------------
   2. TACGIA(MATG, TENTG, NAMSINH, QUOCTICH)
   --------------------------------------------------------------------- */
CREATE TABLE TACGIA
(
	MATG		CHAR(5)			PRIMARY KEY,
	TENTG		NVARCHAR(50)	NOT NULL,
	NAMSINH		INT				NULL,
	QUOCTICH	NVARCHAR(30)	NULL,
	CONSTRAINT CK_TACGIA_NAMSINH CHECK (NAMSINH IS NULL OR NAMSINH BETWEEN 1000 AND YEAR(GETDATE()))
)

/* ---------------------------------------------------------------------
   3. NHAXUATBAN(MANXB, TENNXB, DIACHI, SODT)
   --------------------------------------------------------------------- */
CREATE TABLE NHAXUATBAN
(
	MANXB	CHAR(5)			PRIMARY KEY,
	TENNXB	NVARCHAR(60)	NOT NULL UNIQUE,
	DIACHI	NVARCHAR(100)	NULL,
	SODT	VARCHAR(15)		NULL
)

/* ---------------------------------------------------------------------
   4. DAUSACH(MADS, TENDS, MATL, MANXB, NAMXB, SOTRANG, GIA, SOLUONG, SLCON)
      SOLUONG, SLCON la thuoc tinh dan xuat, duoc trigger cap nhat tu CUONSACH
   --------------------------------------------------------------------- */
CREATE TABLE DAUSACH
(
	MADS	CHAR(5)			PRIMARY KEY,
	TENDS	NVARCHAR(100)	NOT NULL,
	MATL	CHAR(4)			NOT NULL FOREIGN KEY REFERENCES THELOAI (MATL),
	MANXB	CHAR(5)			NOT NULL FOREIGN KEY REFERENCES NHAXUATBAN (MANXB),
	NAMXB	INT				NOT NULL,
	SOTRANG	INT				NOT NULL,
	GIA		MONEY			NOT NULL,
	SOLUONG	INT				NOT NULL DEFAULT 0,
	SLCON	INT				NOT NULL DEFAULT 0,
	CONSTRAINT CK_DAUSACH_NAMXB		CHECK (NAMXB BETWEEN 1900 AND YEAR(GETDATE())),
	CONSTRAINT CK_DAUSACH_SOTRANG	CHECK (SOTRANG > 0),
	CONSTRAINT CK_DAUSACH_GIA		CHECK (GIA > 0),
	CONSTRAINT CK_DAUSACH_SL		CHECK (SOLUONG >= 0 AND SLCON BETWEEN 0 AND SOLUONG)
)

/* ---------------------------------------------------------------------
   5. DAUSACH_TACGIA(MADS, MATG, VAITRO)
   --------------------------------------------------------------------- */
CREATE TABLE DAUSACH_TACGIA
(
	MADS	CHAR(5)			FOREIGN KEY REFERENCES DAUSACH (MADS),
	MATG	CHAR(5)			FOREIGN KEY REFERENCES TACGIA (MATG),
	VAITRO	NVARCHAR(20)	NOT NULL DEFAULT N'Tác giả',
	PRIMARY KEY (MADS, MATG),
	CONSTRAINT CK_DSTG_VAITRO CHECK (VAITRO IN (N'Tác giả', N'Đồng tác giả', N'Dịch giả'))
)

/* ---------------------------------------------------------------------
   6. CUONSACH(MACS, MADS, NGAYNHAP, VITRI, TINHTRANG)
   --------------------------------------------------------------------- */
CREATE TABLE CUONSACH
(
	MACS		CHAR(5)			PRIMARY KEY,
	MADS		CHAR(5)			NOT NULL FOREIGN KEY REFERENCES DAUSACH (MADS),
	NGAYNHAP	DATE			NOT NULL DEFAULT GETDATE(),
	VITRI		NVARCHAR(20)	NULL,
	TINHTRANG	NVARCHAR(20)	NOT NULL DEFAULT N'Có sẵn',
	CONSTRAINT CK_CUONSACH_TINHTRANG CHECK (TINHTRANG IN (N'Có sẵn', N'Đang mượn', N'Hư hỏng', N'Mất'))
)

/* ---------------------------------------------------------------------
   7. LOAIDOCGIA(MALDG, TENLDG, SOSACHTOIDA, SONGAYMUON)
   --------------------------------------------------------------------- */
CREATE TABLE LOAIDOCGIA
(
	MALDG		CHAR(2)			PRIMARY KEY,
	TENLDG		NVARCHAR(30)	NOT NULL UNIQUE,
	SOSACHTOIDA	INT				NOT NULL,
	SONGAYMUON	INT				NOT NULL,
	CONSTRAINT CK_LDG_SOSACH	CHECK (SOSACHTOIDA > 0),
	CONSTRAINT CK_LDG_SONGAY	CHECK (SONGAYMUON > 0)
)

/* ---------------------------------------------------------------------
   8. DOCGIA(MADG, HOTEN, NGSINH, GIOITINH, DIACHI, SODT, EMAIL, MALDG,
             NGAYLAPTHE, NGAYHETHAN, TONGNO)
      TONGNO la thuoc tinh dan xuat (tong tien phat chua thanh toan)
   --------------------------------------------------------------------- */
CREATE TABLE DOCGIA
(
	MADG		CHAR(5)			PRIMARY KEY,
	HOTEN		NVARCHAR(40)	NOT NULL,
	NGSINH		DATE			NOT NULL,
	GIOITINH	NVARCHAR(3)		NOT NULL,
	DIACHI		NVARCHAR(100)	NULL,
	SODT		VARCHAR(15)		NOT NULL,
	EMAIL		VARCHAR(50)		NULL,
	MALDG		CHAR(2)			NOT NULL FOREIGN KEY REFERENCES LOAIDOCGIA (MALDG),
	NGAYLAPTHE	DATE			NOT NULL DEFAULT GETDATE(),
	NGAYHETHAN	DATE			NOT NULL,
	TONGNO		MONEY			NOT NULL DEFAULT 0,
	CONSTRAINT CK_DOCGIA_GIOITINH	CHECK (GIOITINH IN (N'Nam', N'Nữ')),
	CONSTRAINT CK_DOCGIA_NGAYTHE	CHECK (NGAYHETHAN > NGAYLAPTHE),
	CONSTRAINT CK_DOCGIA_TUOI		CHECK (DATEDIFF(YEAR, NGSINH, NGAYLAPTHE) >= 16),
	CONSTRAINT CK_DOCGIA_TONGNO		CHECK (TONGNO >= 0),
	CONSTRAINT CK_DOCGIA_EMAIL		CHECK (EMAIL IS NULL OR EMAIL LIKE '%_@_%._%')
)

/* ---------------------------------------------------------------------
   9. NHANVIEN(MANV, HOTEN, NGSINH, SODT, CHUCVU, NGVL)
   --------------------------------------------------------------------- */
CREATE TABLE NHANVIEN
(
	MANV	CHAR(4)			PRIMARY KEY,
	HOTEN	NVARCHAR(40)	NOT NULL,
	NGSINH	DATE			NOT NULL,
	SODT	VARCHAR(15)		NOT NULL,
	CHUCVU	NVARCHAR(20)	NOT NULL,
	NGVL	DATE			NOT NULL,
	CONSTRAINT CK_NHANVIEN_CHUCVU	CHECK (CHUCVU IN (N'Quản lý', N'Thủ thư', N'Kỹ thuật viên')),
	CONSTRAINT CK_NHANVIEN_NGVL		CHECK (DATEDIFF(YEAR, NGSINH, NGVL) >= 18)
)

/* ---------------------------------------------------------------------
   10. PHIEUMUON(MAPM, MADG, MANV, NGAYMUON, HANTRA, TINHTRANG)
   --------------------------------------------------------------------- */
CREATE TABLE PHIEUMUON
(
	MAPM		CHAR(6)			PRIMARY KEY,
	MADG		CHAR(5)			NOT NULL FOREIGN KEY REFERENCES DOCGIA (MADG),
	MANV		CHAR(4)			NOT NULL FOREIGN KEY REFERENCES NHANVIEN (MANV),
	NGAYMUON	DATE			NOT NULL DEFAULT GETDATE(),
	HANTRA		DATE			NOT NULL,
	TINHTRANG	NVARCHAR(20)	NOT NULL DEFAULT N'Đang mượn',
	CONSTRAINT CK_PHIEUMUON_HANTRA		CHECK (HANTRA > NGAYMUON),
	CONSTRAINT CK_PHIEUMUON_TINHTRANG	CHECK (TINHTRANG IN (N'Đang mượn', N'Đã trả'))
)

/* ---------------------------------------------------------------------
   11. CTPHIEUMUON(MAPM, MACS, NGAYTRA, TINHTRANGTRA)
   --------------------------------------------------------------------- */
CREATE TABLE CTPHIEUMUON
(
	MAPM			CHAR(6)			FOREIGN KEY REFERENCES PHIEUMUON (MAPM),
	MACS			CHAR(5)			FOREIGN KEY REFERENCES CUONSACH (MACS),
	NGAYTRA			DATE			NULL,
	TINHTRANGTRA	NVARCHAR(20)	NULL,
	PRIMARY KEY (MAPM, MACS),
	CONSTRAINT CK_CTPM_TINHTRANGTRA CHECK (TINHTRANGTRA IN (N'Bình thường', N'Hư hỏng', N'Mất')),
	-- Da tra thi phai co tinh trang tra, chua tra thi khong co
	CONSTRAINT CK_CTPM_TRASACH CHECK ((NGAYTRA IS NULL AND TINHTRANGTRA IS NULL)
								   OR (NGAYTRA IS NOT NULL AND TINHTRANGTRA IS NOT NULL))
)

/* ---------------------------------------------------------------------
   12. PHIEUPHAT(MAPP, MAPM, MACS, NGAYLAP, LYDO, SOTIEN, DATHANHTOAN)
   --------------------------------------------------------------------- */
CREATE TABLE PHIEUPHAT
(
	MAPP		CHAR(6)			PRIMARY KEY,
	MAPM		CHAR(6)			NOT NULL,
	MACS		CHAR(5)			NOT NULL,
	NGAYLAP		DATE			NOT NULL DEFAULT GETDATE(),
	LYDO		NVARCHAR(20)	NOT NULL,
	SOTIEN		MONEY			NOT NULL,
	DATHANHTOAN	BIT				NOT NULL DEFAULT 0,
	FOREIGN KEY (MAPM, MACS) REFERENCES CTPHIEUMUON (MAPM, MACS),
	CONSTRAINT CK_PHIEUPHAT_LYDO	CHECK (LYDO IN (N'Trả trễ', N'Hư hỏng', N'Mất sách')),
	CONSTRAINT CK_PHIEUPHAT_SOTIEN	CHECK (SOTIEN > 0)
)

/* ---------------------------------------------------------------------
   13. TAIKHOAN(TENDANGNHAP, MATKHAU, MUOI, VAITRO, MANV, MADG, TRANGTHAI)
       Dung cho chuc nang xac thuc cua ung dung. Mat khau duoc bam SHA2_256
       kem chuoi muoi (salt), khong luu mat khau goc.
   --------------------------------------------------------------------- */
CREATE TABLE TAIKHOAN
(
	TENDANGNHAP	VARCHAR(30)			PRIMARY KEY,
	MATKHAU		VARBINARY(32)		NOT NULL,
	MUOI		UNIQUEIDENTIFIER	NOT NULL,
	VAITRO		NVARCHAR(20)		NOT NULL,
	MANV		CHAR(4)				NULL FOREIGN KEY REFERENCES NHANVIEN (MANV),
	MADG		CHAR(5)				NULL FOREIGN KEY REFERENCES DOCGIA (MADG),
	TRANGTHAI	BIT					NOT NULL DEFAULT 1,
	CONSTRAINT CK_TAIKHOAN_VAITRO CHECK (VAITRO IN (N'Quản lý', N'Thủ thư', N'Độc giả')),
	CONSTRAINT CK_TAIKHOAN_CHUSOHUU CHECK (
		(VAITRO = N'Độc giả' AND MADG IS NOT NULL AND MANV IS NULL)
	 OR (VAITRO <> N'Độc giả' AND MANV IS NOT NULL AND MADG IS NULL))
)
GO
