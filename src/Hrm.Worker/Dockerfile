# syntax=docker/dockerfile:1

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY src/Hrm.Worker/Hrm.Worker.csproj src/Hrm.Worker/
RUN dotnet restore src/Hrm.Worker/Hrm.Worker.csproj

COPY . ./
RUN dotnet publish src/Hrm.Worker/Hrm.Worker.csproj -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/runtime:8.0 AS runtime
WORKDIR /app

ENV DOTNET_EnableDiagnostics=0

COPY --from=build /app/publish ./

ENTRYPOINT ["dotnet", "Hrm.Worker.dll"]
