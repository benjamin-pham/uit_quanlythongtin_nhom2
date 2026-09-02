# QuanLyThuVien (Library Management System)

Đây là dự án ứng dụng web Quản lý Thư viện.

## Công nghệ sử dụng (Tech Stack)

* **Frontend:** React 19, TypeScript, Vite, Tailwind CSS 4, shadcn/ui
* **Backend:** ASP.NET Core Web API
* **Database:** Microsoft SQL Server
* **Orchestration:** .NET Aspire

## Cấu trúc dự án

* `frontend/`: Ứng dụng frontend sử dụng Vite + React.
* `QuanLyThuVien.Server/`: Backend API sử dụng ASP.NET Core.
* `QuanLyThuVien.AppHost/`: Dự án .NET Aspire AppHost để quản lý và điều phối các dịch vụ khi chạy ở môi trường phát triển (local).
* `docker-compose.mssql.yml`: File cấu hình Docker Compose để chạy cơ sở dữ liệu SQL Server ở local.

## Yêu cầu môi trường (Prerequisites)

Trước khi chạy dự án, hãy đảm bảo bạn đã cài đặt các công cụ sau:

* [.NET 10 SDK](https://dotnet.microsoft.com/download) (hoặc mới hơn) cùng với workload .NET Aspire
* [Node.js](https://nodejs.org/) (phiên bản 20.19.0 trở lên)
* [Docker Engine](https://docs.docker.com/engine/install/) (để chạy SQL Server)

## Hướng dẫn chạy dự án

### 1. Khởi động Database

Dự án sử dụng SQL Server. Bạn có thể sử dụng Docker Compose để khởi chạy một instance cục bộ nhanh chóng:

```bash
docker-compose -f docker-compose.mssql.yml up -d
```
*Lệnh này sẽ khởi chạy SQL Server ở địa chỉ `localhost:1444`.*

### 2. Cài đặt các gói NPM (Frontend)

Mở terminal ở thư mục `frontend` và cài đặt các dependencies:

```bash
cd frontend
npm install
```

### 3. Chạy ứng dụng

Dự án này sử dụng **.NET Aspire** để quản lý đồng thời cả backend và frontend.

Tại thư mục gốc của dự án, chạy lệnh sau:

```bash
dotnet run --project QuanLyThuVien.AppHost
```

Lệnh này sẽ tự động thực hiện:
1. Khởi chạy backend ASP.NET Core.
2. Khởi chạy frontend Vite React.
3. Mở **.NET Aspire Dashboard** trên trình duyệt của bạn, tại đây bạn có thể xem log, các endpoint và quản lý các service đang chạy.

