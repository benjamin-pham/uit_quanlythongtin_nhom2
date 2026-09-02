using Dapper;
using QuanLyThuVien.Server.Shared;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace QuanLyThuVien.Server.Endpoints;

public class TestDbEndpoint : IEndpoint
{
    public void MapEndpoint(IEndpointRouteBuilder app)
    {
        app.MapGet("api/test-db", async (System.Data.IDbConnection db) =>
        {
            var version = await SqlMapper.QueryFirstAsync<string>(db, "SELECT @@VERSION");

            return Results.Ok(new
            {
                Message = "Kết nối CSDL thành công!",
                SqlServerVersion = version
            });
        })
        .WithName("TestDatabaseConnection")
        .WithTags("Test")
        .WithGroupName("v1");
    }
}

