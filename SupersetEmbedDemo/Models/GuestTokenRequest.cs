using System.Collections.Generic;

namespace SupersetEmbedDemo.Models
{
    public class GuestTokenRequest
    {
        public string DashboardUuid { get; set; }
        public SupersetUser User { get; set; }
        public List<RlsRule> RowLevelSecurity { get; set; }

        public GuestTokenRequest()
        {
            RowLevelSecurity = new List<RlsRule>();
        }
    }

    public class RlsRule
    {
        public string Clause { get; set; }
        public int? DatasetId { get; set; }
    }
}
