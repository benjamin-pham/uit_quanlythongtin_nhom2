var builder = DistributedApplication.CreateBuilder(args);

var mssql = builder.AddConnectionString("mssql", "Server=localhost,1444;Database=master;User Id=sa;Password=Str0ngP4ssw0rd!;TrustServerCertificate=True");

var server = builder.AddProject<Projects.QuanLyThuVien_Server>("server")
    .WithReference(mssql)
    .WithHttpHealthCheck("/health")
    .WithExternalHttpEndpoints();

var webfrontend = builder.AddViteApp("webfrontend", "../frontend")
    .WithReference(server)
    .WaitFor(server);

server.PublishWithContainerFiles(webfrontend, "wwwroot");

builder.Build().Run();
