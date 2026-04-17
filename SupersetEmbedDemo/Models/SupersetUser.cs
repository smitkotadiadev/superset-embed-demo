namespace SupersetEmbedDemo.Models
{
    public class SupersetUser
    {
        public string Username { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string Email { get; set; }
        public string TenantId { get; set; }
        public string Role { get; set; }

        public static SupersetUser Anonymous()
        {
            return new SupersetUser
            {
                Username = "guest",
                FirstName = "Guest",
                LastName = "User",
                Email = "guest@example.com",
                TenantId = "default",
                Role = "Viewer"
            };
        }
    }
}
