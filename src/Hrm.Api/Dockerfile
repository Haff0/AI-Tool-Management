# syntax=docker/dockerfile:1

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy toàn bộ code từ thư mục mẹ vào (bao gồm AI, ConnectAI, ToolHelper do dùng context "..")
COPY AI-Tool-Management/ AI-Tool-Management/
COPY ConnectAI/ ConnectAI/

WORKDIR /src/AI-Tool-Management
# Publish Hrm.Api
RUN dotnet publish src/Hrm.Api/Hrm.Api.csproj -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

ENV DOTNET_EnableDiagnostics=0
ENV ASPNETCORE_URLS=http://+:8080

COPY --from=build /app/publish ./

EXPOSE 8080
ENTRYPOINT ["dotnet", "Hrm.Api.dll"]