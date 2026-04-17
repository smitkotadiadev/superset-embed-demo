using System;
using System.Collections.Generic;

namespace SupersetEmbedDemo.Models
{
    public class DashboardInfo
    {
        public int Id { get; set; }
        public string Uuid { get; set; }
        public string Title { get; set; }
        public string Slug { get; set; }
        public string Description { get; set; }
        public string Status { get; set; }
        public string Owner { get; set; }
        public DateTime ChangedOn { get; set; }
        public bool Published { get; set; }
        public bool EmbedEnabled { get; set; }
        public List<string> Tags { get; set; }

        public DashboardInfo()
        {
            Tags = new List<string>();
        }
    }
}
