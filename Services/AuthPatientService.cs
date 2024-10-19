using System;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using TodoApi.Models;
using Microsoft.Extensions.Options;

namespace TodoApi.Services
{
    public class AuthPatientService
    {
        private readonly HttpClient _httpClient;
        private readonly Auth0Settings _auth0Settings;
        private readonly UserContext _context;

        public AuthPatientService(HttpClient httpClient, IOptions<Auth0Settings> auth0Settings, UserContext context)
        {
            _httpClient = httpClient;
            _auth0Settings = auth0Settings.Value;
            _context = context;
        }

        public async Task AuthenticateUser(string state)
        {
            var domain = _auth0Settings.Domain;
            var clientId = _auth0Settings.ClientId;
            var redirectUri = "https://localhost:5001/api/Patients/callback"; // Redirect URI

            // Construct the authorization URL with the state parameter
            var authorizationUrl = $"https://{domain}/authorize?response_type=code&client_id={clientId}&redirect_uri={redirectUri}&scope=openid profile email&state={state}&prompt=login";
            Console.WriteLine($"Redirecting to Auth0 for authentication: {authorizationUrl}");

            // Automatically open the Auth0 login page
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
            {
                FileName = authorizationUrl,
                UseShellExecute = true
            });
        }

        public async Task<string> WaitForCodeAsync(string code)
        {
            Console.WriteLine($"[Authorization Code] Received: {code}");

            var domain = _auth0Settings.Domain;
            var clientId = _auth0Settings.ClientId;
            var redirectUri = "https://localhost:5001/api/Patients/callback";

            if (!string.IsNullOrEmpty(code))
            {
                // Exchange the authorization code for an access token and ID token
                var tokenUrl = $"https://{domain}/oauth/token";
                var tokenPayload = new
                {
                    client_id = clientId,
                    client_secret = _auth0Settings.ClientSecret,
                    code = code,
                    redirect_uri = redirectUri,
                   grant_type = "authorization_code"
                };

                var json = JsonSerializer.Serialize(tokenPayload);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                // Log the token exchange request
                Console.WriteLine("[Token Exchange] Sending request to Auth0...");


                // Send request to Auth0 using the injected HttpClient
                var response = await _httpClient.PostAsync(tokenUrl, content);
               if (response.IsSuccessStatusCode)
                {
                    var result = await response.Content.ReadAsStringAsync();
                    Console.WriteLine("Token Response: " + result); // Log the entire response

                    var tokenResponse = JsonSerializer.Deserialize<JsonElement>(result);
                    var accessToken = tokenResponse.GetProperty("access_token").GetString();
                    var idToken = tokenResponse.GetProperty("id_token").GetString(); // Extract ID token

                    return idToken; // Return ID token or access token based on your need
                }
                else
                {
                    Console.WriteLine($"Error obtaining token: {response.StatusCode}");
                }
            }
            return null;
        }


        public async Task<Patient> CreateProfileAsync(PatientRegistrationDto model, string email)
        {
            var patient = new Patient
            {
                Email = email,
                UserName = model.UserName,
                FirstName = model.FirstName,
                LastName = model.LastName,
                Birthday = model.Birthday,
                Gender = model.Gender,
                PhoneNumber = model.PhoneNumber,
                MedicalConditions = model.MedicalConditions,
                EmergencyContact = model.EmergencyContact,
                Role = Roles.Patient
            };

            _context.Patients.Add(patient);
            await _context.SaveChangesAsync();

            return patient;
        }
    }
}
