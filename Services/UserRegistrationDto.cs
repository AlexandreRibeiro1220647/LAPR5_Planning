using TodoApi.Models;

namespace TodoApi.Services;

public class UserRegistrationDto
{
    public string? Email { get; set; }
    public string? Password { get; set; }
    public string? FirstName { get; set; }
    public string? LastName { get; set; }
    public Roles Role { get; set; }  // Enum role
}
