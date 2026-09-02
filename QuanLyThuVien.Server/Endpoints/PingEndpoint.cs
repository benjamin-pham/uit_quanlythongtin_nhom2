using QuanLyThuVien.Server.Shared;

namespace QuanLyThuVien.Server.Endpoints;

public class PingEndpoint : IEndpoint
{
    public void MapEndpoint(IEndpointRouteBuilder app)
    {
        app.MapGet("ping", () => "pong!")
            .WithName("ping")
            .WithTags("ping")
            .WithGroupName("v1");
    }
}

