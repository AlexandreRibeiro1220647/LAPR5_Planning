public class PatientRegistrationDto
{
    public string? UserName { get; set; }
    public string? FirstName { get; set; }
    public string? LastName { get; set; }
    public DateTime Birthday { get; set; }
    public string? Gender { get; set; }
    public string? PhoneNumber { get; set; }
    public List<string> MedicalConditions { get; set; } = new List<string>();
    public string? EmergencyContact { get; set; }
}
