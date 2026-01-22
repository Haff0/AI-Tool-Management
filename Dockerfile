# syntax=docker/dockerfile:1

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy csproj first for better layer caching
COPY AI-Tool-Management.csproj ./
RUN dotnet restore ./AI-Tool-Management.csproj

# Copy everything else
COPY . ./
RUN dotnet publish ./AI-Tool-Management.csproj -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# Disable diagnostics for lighter prod containers
ENV DOTNET_EnableDiagnostics=0
ENV ASPNETCORE_URLS=http://+:8080

COPY --from=build /app/publish ./

EXPOSE 8080
ENTRYPOINT ["dotnet", "AI-Tool-Management.dll"]
