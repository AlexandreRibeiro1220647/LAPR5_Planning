using Microsoft.EntityFrameworkCore;

namespace TodoApi.Models;

public class UserContext : DbContext
{
    public UserContext(DbContextOptions<UserContext> options)
        : base(options)
    {
    }

    public DbSet<User> Users { get; set; } 
    public DbSet<Patient> Patients { get; set; } 

     protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<User>()
                .ToTable("Users"); 
            
            modelBuilder.Entity<Patient>()
                .ToTable("Patients"); 
        }
    
}