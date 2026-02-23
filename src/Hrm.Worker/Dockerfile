# syntax=docker/dockerfile:1

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy toàn bộ code từ thư mục mẹ vào (bao gồm AI, ConnectAI, ToolHelper)
COPY AI-Tool-Management/ AI-Tool-Management/
COPY ConnectAI/ ConnectAI/

WORKDIR /src/AI-Tool-Management
# Publish Hrm.Worker
RUN dotnet publish src/Hrm.Worker/Hrm.Worker.csproj -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/runtime:8.0 AS runtime
WORKDIR /app

ENV DOTNET_EnableDiagnostics=0

COPY --from=build /app/publish ./

ENTRYPOINT ["dotnet", "Hrm.Worker.dll"]
