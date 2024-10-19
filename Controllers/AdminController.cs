using Microsoft.AspNetCore.Mvc;
using TodoApi.Models;
using TodoApi.Services;

namespace TodoApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AdminController : ControllerBase
    {
        private readonly UserContext _context;
        private readonly UserRegistrationService _userRegistrationService;

        public AdminController(UserContext context, UserRegistrationService userRegistrationService)
        {
            _context = context;
            _userRegistrationService = userRegistrationService;
        }

        [HttpPost("Register")]
        public async Task<IActionResult> RegisterUser([FromBody] UserRegistrationDto model)
        {
            var user = await _userRegistrationService.RegisterUser(model);

            user = await _context.Users.FindAsync(user.Id);

            if (user == null)
            {
                return NotFound();
            }

            return CreatedAtAction(nameof(user), "Users", new { id = user.Id }, user);
        }
    }
}
