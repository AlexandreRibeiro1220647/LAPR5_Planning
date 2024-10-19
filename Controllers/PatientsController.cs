using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TodoApi.Models;
using TodoApi.Services;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Authentication;
using System.Security.Claims;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;


namespace TodoApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class PatientsController : ControllerBase
    {
        private readonly UserContext _context;
        private readonly AuthPatientService _authPatientService;

        public PatientsController(UserContext context, AuthPatientService authPatientService)
        {
            _context = context;
            _authPatientService = authPatientService;
        }

        // GET: api/Patients
        [HttpGet]
        public async Task<ActionResult<IEnumerable<Patient>>> GetPatients()
        {
            return await _context.Patients.ToListAsync();
        }

    

        // GET: api/Patients/5
        [HttpGet("{id}")]
        public async Task<ActionResult<Patient>> GetPatient(long id)
        {
            var patient = await _context.Patients.FindAsync(id);

            if (patient == null)
            {
                return NotFound();
            }

            return patient;
        }

        // GET: api/Patients/email/{email}
        [HttpGet("email/{email}")]
        public async Task<ActionResult<Patient>> GetPatientByEmail(string email)
        {
            var patient = await _context.Patients.FirstOrDefaultAsync(p => p.Email == email);

            if (patient == null)
            {
                return NotFound();
            }

            return Ok(patient);
        }

        // POST: api/Patients
        [HttpPost]
        public async Task<ActionResult<Patient>> PostPatient(Patient patient)
        {
            _context.Patients.Add(patient);
            await _context.SaveChangesAsync();

            return CreatedAtAction("GetPatient", new { id = patient.Id }, patient);
        }

        // PUT: api/Patients/5
        [HttpPut("{id}")]
        public async Task<IActionResult> PutPatient(long id, Patient patient)
        {
            if (id != patient.Id)
            {
                return BadRequest();
            }

            _context.Entry(patient).State = EntityState.Modified;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!PatientExists(id))
                {
                    return NotFound();
                }
                else
                {
                    throw;
                }
            }

            return NoContent();
        }

        // DELETE: api/Patients/5
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeletePatient(long id)
        {
            var patient = await _context.Patients.FindAsync(id);
            if (patient == null)
            {
                return NotFound();
            }

            _context.Patients.Remove(patient);
            await _context.SaveChangesAsync();

            return NoContent();
        }

        private bool PatientExists(long id)
        {
            return _context.Patients.Any(e => e.Id == id);
        }


[HttpPost("authenticate")]
public IActionResult AuthenticateUser()
{
    // Add CORS headers
    Response.Headers.Add("Access-Control-Allow-Origin", "https://localhost:5001");
    Response.Headers.Add("Access-Control-Allow-Credentials", "true");

    return Challenge(new AuthenticationProperties
    {
        RedirectUri = "/api/Patients/callback"
    }, "Auth0");
}

[HttpGet("callback")]
public async Task<IActionResult> Callback([FromQuery] string code, [FromQuery] string state)
{

        // Log the state received from the Auth0 callback
    Console.WriteLine($"[State] Received from Auth0: {state}");


    // Retrieve the original state from session (instead of cookie)
    var originalState = HttpContext.Session.GetString("OAuthState");
    if (originalState == null)
    {
        return BadRequest("State not found in session");
    }


    Console.WriteLine($"[State] Original state retrieved from cookie: {originalState}");


    // Clear the state from session
    HttpContext.Session.Remove("OAuthState");

    // Validate the state parameter
    if (state != originalState)
    {
        return BadRequest("Invalid state parameter");
    }

    var token = await _authPatientService.WaitForCodeAsync(code);
    if (string.IsNullOrEmpty(token))
    {
        return Unauthorized();
    }

    // Set the access token in a cookie
    var cookieOptions = new CookieOptions
    {
        HttpOnly = true,
        Secure = false,
        SameSite = SameSiteMode.Strict,
        Expires = DateTimeOffset.UtcNow.AddMinutes(10)
    };

    Response.Cookies.Append("access_token", token, cookieOptions);

    return Redirect("profile/create");
}


        // <summary>
        /// Handles the form submission for completing a patient profile.
        /// </summary>
        [Authorize]
        [HttpPost("profile/create")]
        public async Task<IActionResult> CreateProfile([FromBody] PatientRegistrationDto model)
        {
            if (ModelState.IsValid)
            {
                string email = User.FindFirst(ClaimTypes.Email)?.Value; // Get email from Auth0 claims
                var patient = await _authPatientService.CreateProfileAsync(model, email);

                var user = await _context.Users.FindAsync(patient.Id);

                if (user == null)
                {
                    return NotFound();
                }

                return CreatedAtAction(nameof(user), "Users", new { id = user.Id }, user);
            }

            return BadRequest(ModelState);

        }

    }
}
