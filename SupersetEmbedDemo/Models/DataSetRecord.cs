using System;
using System.Collections.Generic;

namespace SupersetEmbedDemo.Models
{
    public class DataSetRecord
    {
        public string Id { get; set; }
        public string Region { get; set; }
        public string Product { get; set; }
        public string Category { get; set; }
        public decimal Revenue { get; set; }
        public int Units { get; set; }
        public DateTime SaleDate { get; set; }
        public string SalesRep { get; set; }
    }

    public class DataSetResponse
    {
        public int Total { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
        public List<DataSetRecord> Records { get; set; }

        public DataSetResponse()
        {
            Records = new List<DataSetRecord>();
        }
    }
}
