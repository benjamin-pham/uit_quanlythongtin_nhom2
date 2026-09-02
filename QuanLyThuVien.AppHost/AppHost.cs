var builder = DistributedApplication.CreateBuilder(args);

var database = builder.AddSqlServer("Database")
                   .WithDataVolume()
                   .AddDatabase("QuanLyThuVien");

var server = builder.AddProject<Projects.QuanLyThuVien_Server>("Backend")
    .WithReference(database)
    .WithHttpHealthCheck("/health")
    .WithExternalHttpEndpoints();

var webfrontend = builder.AddViteApp("Frontend", "../frontend")
    .WithReference(server)
    .WaitFor(server);

server.PublishWithContainerFiles(webfrontend, "wwwroot");

builder.Build().Run();
