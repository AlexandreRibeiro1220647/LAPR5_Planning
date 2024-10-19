using TodoApi.Models;

namespace TodoApi.Services
{
    public class UserRegistrationService
    {
        private readonly UserContext _context;

        public UserRegistrationService(UserContext context)
        {
            _context = context;
        }

        public async Task<User> RegisterUser(UserRegistrationDto model)
        {
            var user = new User
            {
                Email = model.Email,
                UserName = model.Email,
                FirstName = model.FirstName,
                LastName = model.LastName,
                Role = model.Role
            };

            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            return user;
        }
    }
}
