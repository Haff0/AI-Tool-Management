using MediatR;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace Hrm.Application.Features.Auth.Login;

public record LoginCommand(string Username, string Password) : IRequest<string>;

public class LoginCommandHandler : IRequestHandler<LoginCommand, string>
{
    private readonly IConfiguration _configuration;

    public LoginCommandHandler(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public Task<string> Handle(LoginCommand request, CancellationToken cancellationToken)
    {
        // Mocking user validation here. In reality, this would query a UserRepository.
        // We simulate a Level 1 User and a Level 2 Manager for testing.
        string roleLevel = "Level1_Employee";
        
        if (request.Username == "admin" && request.Password == "admin")
        {
            roleLevel = "Level2_Manager";
        }
        else if (request.Username != "user" || request.Password != "password")
        {
            throw new UnauthorizedAccessException("Invalid credentials.");
        }

        var jwtKey = _configuration["Jwt:Key"] ?? "superSecretKeyThatIsAtLeast32BytesLong123!";
        var jwtIssuer = _configuration["Jwt:Issuer"] ?? "HrmApp";
        var jwtAudience = _configuration["Jwt:Audience"] ?? "HrmAppScope";

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString()),
            new Claim(ClaimTypes.Name, request.Username),
            new Claim("RoleLevel", roleLevel)
        };

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Expires = DateTime.UtcNow.AddHours(2),
            Issuer = jwtIssuer,
            Audience = jwtAudience,
            SigningCredentials = creds
        };

        var tokenHandler = new JwtSecurityTokenHandler();
        var token = tokenHandler.CreateToken(tokenDescriptor);

        return Task.FromResult(tokenHandler.WriteToken(token));
    }
}
