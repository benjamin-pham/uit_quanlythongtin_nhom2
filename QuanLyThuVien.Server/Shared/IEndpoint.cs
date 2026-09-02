using Microsoft.AspNetCore.Routing;

namespace QuanLyThuVien.Server.Shared;

public interface IEndpoint
{
    void MapEndpoint(IEndpointRouteBuilder app);
}

