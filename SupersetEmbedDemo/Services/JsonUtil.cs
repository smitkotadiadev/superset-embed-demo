using System.Collections.Generic;
using System.Web.Script.Serialization;

namespace SupersetEmbedDemo.Services
{
    public static class JsonUtil
    {
        private static readonly JavaScriptSerializer _serializer = CreateSerializer();

        private static JavaScriptSerializer CreateSerializer()
        {
            var s = new JavaScriptSerializer();
            s.MaxJsonLength = int.MaxValue;
            return s;
        }

        public static string Serialize(object value)
        {
            return _serializer.Serialize(value);
        }

        public static T Deserialize<T>(string json)
        {
            if (string.IsNullOrEmpty(json))
            {
                return default(T);
            }
            return _serializer.Deserialize<T>(json);
        }

        public static Dictionary<string, object> ParseObject(string json)
        {
            return Deserialize<Dictionary<string, object>>(json);
        }
    }
}
