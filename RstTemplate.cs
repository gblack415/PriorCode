/*
 * Name:YhRstTemplate
 * Created by VS2008C#.
 * Compiling: VC#2008 works
 * User: garbla
 * Date: 05/29/2020
 *
 * 
 */
using PHAuthSpace;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;
using System.ServiceModel;
using System.ServiceModel.Web;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Xml;
using System.Web;
using System.Web.UI;
using System.Web.Script.Serialization;

namespace YhRstTemplateSpace
{
    class YhRstTemplate
    {
        int totTemplate, totFields;
        SqlConnection SqlCon;
        PHAuthenticator PhAuth;
        List<IncidentClass> IncidentList;
        StringBuilder SqlTable, SqlField;

        static void Main(string[] args)
        {
            YhRstTemplate Yh = new YhRstTemplate();
            Yh.RunIt();
//#if DEBUG
//            Thread.Sleep(10000);
//#endif
        }
        public YhRstTemplate()
        {
            totFields = 0;
            totTemplate = 0;
            PhAuth = new PHAuthenticator();
            if (PhAuth.ExitOnSuspendFile())
            {
                Environment.ExitCode = 1;
                Console.WriteLine("Found Suspend File, Bye\n");
                PhAuth.LogMessage(System.AppDomain.CurrentDomain.FriendlyName, "Found Suspend File, Bye");
                System.Environment.Exit(1);
            }
            PhAuth.YhCreateTokens();
            IncidentList = new List<IncidentClass>();
            SqlCon = new SqlConnection(PhAuth.GetSQLString());
            SqlCon.Open();
            SqlTable = new StringBuilder();
            SqlTable.Append("MERGE INTO dbo.Yh_busob as d USING (select ");
            SqlTable.Append("@OBID as obid, ");
            SqlTable.Append("@OBNAME as obName, ");
            SqlTable.Append("@OBDNAME as obDName ");
            //SqlTable.Append("@OBDESC as obDesc ");
            SqlTable.Append(") as s ");
            SqlTable.Append("ON (Yhbo_obid = obid) ");
            //SqlTable.Append("WHEN MATCHED THEN UPDATE SET Yhbo_name=obName,Yhbo_displayname=obDName,Yhbo_description=obDesc ");
            SqlTable.Append("WHEN MATCHED THEN UPDATE SET Yhbo_name=obName,Yhbo_displayname=obDName ");
            //SqlTable.Append("WHEN NOT MATCHED THEN INSERT (Yhbo_environment,Yhbo_obid,Yhbo_name,Yhbo_displayname,Yhbo_description) values(Yhenv,obid,obName,obDName,obDesc);");
            SqlTable.Append("WHEN NOT MATCHED THEN INSERT (Yhbo_obid,Yhbo_name,Yhbo_displayname) values(obid,obName,obDName);");

            SqlField = new StringBuilder();
            SqlField.Append("MERGE INTO dbo.[Yh_busobField] as d USING (select ");
            SqlField.Append("@OBID as obid, ");
            SqlField.Append("@FID as fid, ");
            SqlField.Append("@OBNAME as obName, ");
            SqlField.Append("@OBDNAME as obDName, ");
            SqlField.Append("@OBTYPE as obType, ");
            SqlField.Append("@OBLEN as oblen, ");
            SqlField.Append("@OBDESC as obDesc ");
            SqlField.Append(") as s ");
            //SqlField.Append("ON (Yhbof_Environment = Yhenv and Yhbof_obid = obid and Yhbof_fid = fid) ");
            SqlField.Append("ON (Yhbof_obid = obid and Yhbof_fid = fid) ");
            //SqlField.Append("WHEN MATCHED THEN UPDATE SET Yhbof_name=obName,Yhbof_displayname=obDName,Yhbof_type=obType,Yhbof_length=obLen,Yhbof_description=obDesc ");
            //SqlField.Append("WHEN NOT MATCHED THEN INSERT (Yhbof_environment,Yhbof_obid,Yhbof_fid,Yhbof_name,Yhbof_displayname,Yhbof_type,Yhbof_length,Yhbof_description) values(Yhenv,obid,fid,obName,obDName,obType,obLen,obDesc);");
            SqlField.Append("WHEN MATCHED THEN UPDATE SET Yhbof_name=obName,Yhbof_displayname=obDName,Yhbof_type=obType,Yhbof_length=obLen,Yhbof_description=obDesc ");
            SqlField.Append("WHEN NOT MATCHED THEN INSERT (Yhbof_obid,Yhbof_fid,Yhbof_name,Yhbof_displayname,Yhbof_type,Yhbof_length,Yhbof_description) values(obid,fid,obName,obDName,obType,obLen,obDesc);");
        }
        void RunIt()
        {
            PhAuth.LogMessage(System.AppDomain.CurrentDomain.FriendlyName, "Started");
            if (PhAuth.YhAccessToken != null && PhAuth.YhRefreshToken != null)
            {

                FindTemplate("/api/V1/getYahooObjectsummaries/type/All");
                if (PhAuth.ExitOnSuspendFile())
                {
                    Environment.ExitCode = 1;
                    Console.WriteLine("Found Suspend File, Bye\n");
                    PhAuth.LogMessage(System.AppDomain.CurrentDomain.FriendlyName, "Found Suspend File, Bye");
                    System.Environment.Exit(1);
                }
                
            }
            PhAuth.LogMessage(System.AppDomain.CurrentDomain.FriendlyName, string.Format("Ended T:{0} F:{1} ", totTemplate, totFields));
        }

        string FindTemplate(string _url)
        {
            string Staff = "";
            var HttpWebRequest = (HttpWebRequest)WebRequest.Create(PhAuth.YhRestUrl + _url);
            HttpWebRequest.Headers.Add("Authorization", string.Format("Bearer {0}", PhAuth.YhAccessToken)); //
            HttpWebRequest.Timeout = 50000;//Cherwell system is real slow even when unloaded
            HttpWebRequest.Proxy = null;
            HttpWebRequest.AllowAutoRedirect = true;
            HttpWebRequest.ContentType = "application/json";
            HttpWebRequest.Method = "GET";
            HttpWebRequest.Accept = "application/json";
            HttpWebRequest.KeepAlive = false;
            HttpWebRequest.ServicePoint.Expect100Continue = false;


            try
            {

                Console.WriteLine("Getting Table Response");
                var httpResponse = (HttpWebResponse)HttpWebRequest.GetResponse(); //This Barfs when encoding specified
                Console.WriteLine("Response Len:{0}", httpResponse.ContentLength.ToString());
                using (var streamReader = new StreamReader(httpResponse.GetResponseStream()))
                {
                    if (HttpWebRequest.HaveResponse)
                    {
    
                        string RawResult = streamReader.ReadToEnd();

                        Debug.WriteLine("Raw:{0}", RawResult);

                        List<YahooObjectSummary> DesResult = new List<YahooObjectSummary>();
                        DeserializeIt(RawResult, ref DesResult);
                        totTemplate = DesResult.Count;
                        Console.WriteLine("BO #:{0}", DesResult.Count);
                        if (DesResult.Count > 0)
                        {
                            foreach (var row in DesResult)
                            {
                                Console.WriteLine("bo id:{0} {1}", row.busObId, row.displayName);
                                SaveTable(row);
                                FindFields(row);
                                if (PhAuth.ExitOnSuspendFile())
                                {
                                    Environment.ExitCode = 1;
                                    Console.WriteLine("Found Suspend File, Bye\n");
                                    PhAuth.LogMessage(System.AppDomain.CurrentDomain.FriendlyName, "Found Suspend File, Bye");
                                    System.Environment.Exit(1);
                                }
                            }
                        }
                        else
                        {
                            Console.WriteLine("no bo:{0}", RawResult);
                        }
                    }
                    streamReader.Close();

                }
                

            }
            catch (WebException e)
            {
                Console.WriteLine("WebException raised!");
                Console.WriteLine("WebMessage: {0}", e.Message);
                Console.WriteLine("WebStatus: {0}", e.Status);
                Console.WriteLine("WebTarget: {0}", e.TargetSite);
                Console.WriteLine("WebSource: {0}", e.Source);
                //https://stackoverflow.com/questions/7261986/how-to-get-error-information-when-HttpWebRequest-getresponse-fails
                using (var stream = e.Response.GetResponseStream())
                using (var reader = new StreamReader(stream))
                {
                    if (reader != null)
                    {
                        string ErrResult = reader.ReadToEnd();
                        Console.WriteLine("Raw {0}", ErrResult);
                    }
                    else
                    {
                        Console.WriteLine("BLANK RESPONSE");
                    }
                }

            }
            catch (Exception e)
            {
                
                Console.WriteLine("Exception raised!");
                Console.WriteLine("Source :{0} ", e.Source);
                Console.WriteLine("Message :{0} ", e.Message);
            }

            return Staff;

        }

        void SaveTable(YahooObjectSummary _table)
        {
            using (SqlCommand SqlCmd = new SqlCommand(SqlTable.ToString(), SqlCon))
            {
                SqlCmd.Parameters.Add("@OBID", SqlDbType.VarChar).Value = _table.busObId;
                SqlCmd.Parameters.Add("@OBDNAME", SqlDbType.VarChar).Value = _table.displayName;
                SqlCmd.Parameters.Add("@OBNAME", SqlDbType.VarChar).Value = _table.name;
                SqlCmd.ExecuteNonQuery();
                SqlCmd.Dispose();
            }
        }

        string FindFields(YahooObjectSummary _table)
        {
            string Staff = "";
            var HttpWebRequest = (HttpWebRequest)WebRequest.Create(string.Format("{0}{1}{2}",PhAuth.YhRestUrl,"/api/V1/getYahooObjectschema/busobid/",_table.busObId));
            HttpWebRequest.Headers.Add("Authorization", string.Format("Bearer {0}", PhAuth.YhAccessToken)); //
            HttpWebRequest.Timeout = 50000;//Cherwell system is real slow even when unloaded
            HttpWebRequest.Proxy = null;
            HttpWebRequest.AllowAutoRedirect = true;
            HttpWebRequest.ContentType = "application/json";
            HttpWebRequest.Method = "GET";
            HttpWebRequest.Accept = "application/json";
            HttpWebRequest.KeepAlive = false;
            HttpWebRequest.ServicePoint.Expect100Continue = false;

            try
            {

                Console.WriteLine("Getting Field Response");
                var httpResponse = (HttpWebResponse)HttpWebRequest.GetResponse(); //This Barfs when encoding specified
                Console.WriteLine("Field Response Len:{0}", httpResponse.ContentLength.ToString());
                using (var streamReader = new StreamReader(httpResponse.GetResponseStream()))
                {
                    if (HttpWebRequest.HaveResponse)
                    {
                        string RawResult = streamReader.ReadToEnd();
                        Debug.WriteLine("Raw:{0}", RawResult);

                        YahooObjectSchema DesResult = new YahooObjectSchema();
                        DeserializeIt(RawResult, ref DesResult);

                        Console.WriteLine("BO #:{0}", DesResult.busObId);
                        if (DesResult.fieldDefinitions.Length > 0)
                        {
                            foreach (var row in DesResult.fieldDefinitions)
                            {
                                //Console.WriteLine("bo:{0} fid:{1}", DesResult.busObId, row.fieldId);
                                Console.WriteLine("{0}", row.fieldId);
                                SaveField(DesResult.busObId,row);
                                totFields++;
                            }
                        }
                        else
                        {
                            Console.WriteLine("no bo:{0}", RawResult);
                        }
                    }
                    streamReader.Close();

                }


            }
            catch (WebException _wex)
            {
                Console.WriteLine("WebException raised!");
                Console.WriteLine("WebMessage: {0}", _wex.Message);
                Console.WriteLine("WebStatus: {0}", _wex.Status);
                Console.WriteLine("WebTarget: {0}", _wex.TargetSite);
                Console.WriteLine("WebSource: {0}", _wex.Source);
                //https://stackoverflow.com/questions/7261986/how-to-get-error-information-when-HttpWebRequest-getresponse-fails
                using (var stream = _wex.Response.GetResponseStream())
                using (var reader = new StreamReader(stream))
                {
                    if (reader != null)
                    {
                        string ErrResult = reader.ReadToEnd();
                        Console.WriteLine("Raw {0}", ErrResult);
                    }
                    else
                    {
                        Console.WriteLine("BLANK RESPONSE");
                    }
                }

            }
            catch (SqlException _sex)
            {
                Console.WriteLine(_sex.Message);
                Console.WriteLine(_sex.InnerException);
                Environment.ExitCode = 1;
                
                PhAuth.LogMessage(System.AppDomain.CurrentDomain.FriendlyName, "SQL Error:" + _sex.Message);
                Console.WriteLine("SQL Error:" + _sex.Message);
            }
            catch (Exception _e)
            {
                Console.WriteLine("Exception raised!");
                Console.WriteLine("Source :{0} ", _e.Source);
                Console.WriteLine("Message :{0} ", _e.Message);
            }

            return Staff;

        }

        void SaveField(string _table,BsaFd _field)
        {
            using (SqlCommand SqlCmd = new SqlCommand(SqlField.ToString(), SqlCon))
            {
                SqlCmd.Parameters.Add("@OBID", SqlDbType.VarChar).Value = _table;
                SqlCmd.Parameters.Add("@FID", SqlDbType.VarChar).Value = Regex.Replace(_field.fieldId, ".*:", string.Empty);
                SqlCmd.Parameters.Add("@OBNAME", SqlDbType.VarChar).Value = _field.name;
                SqlCmd.Parameters.Add("@OBDNAME", SqlDbType.VarChar).Value = _field.displayName;
                SqlCmd.Parameters.Add("@OBTYPE", SqlDbType.VarChar).Value = _field.type;
                if (_field.maximumSize == "Maximum" || _field.maximumSize == "Maximum searchable")
                {
                    SqlCmd.Parameters.Add("@OBLEN", SqlDbType.VarChar).Value = 2147483647;
                }
                else
                {
                    SqlCmd.Parameters.Add("@OBLEN", SqlDbType.VarChar).Value = _field.maximumSize;
                }
                SqlCmd.Parameters.Add("@OBDESC", SqlDbType.VarChar).Value = _field.description;
                SqlCmd.ExecuteNonQuery();
                SqlCmd.Dispose();
            }
        }

        string FindField(RstBo _bo, string _fid)
        {
            return _bo.fields.First(RstField => RstField.fieldId.Contains(_fid)).value;
        }

        void DeserializeIt<T>(string _in, ref T _dout)
        {
            MemoryStream ms = new MemoryStream(Encoding.UTF8.GetBytes(_in));

            DataContractJsonSerializer ser = new DataContractJsonSerializer(_dout.GetType());
            _dout = (T)ser.ReadObject(ms);
        }

    }
    public class IncidentClass
    {
        public string Css;
        public string RecId;
        public IncidentClass(string _css, string _recid)
        {
            Css = _css;
            RecId = _recid;
        }
    }
    //---------------------------------------
    public class RstBos
    {
        public YahooObjectSummary Bos { get; set; }
    }

    public class YahooObjectSummary
    {
    public string firstRecIdField { get; set; }
    //public string[] groupSummaries { get; set; }
    public string recIdFields { get; set; }
    public string stateFieldId { get; set; }
    public string states { get; set; }
    public string busObId { get; set; }
    public string displayName { get; set; }
    public bool group { get; set; }
    public bool lookup { get; set; }
    public bool major { get; set; }
    public string name { get; set; }
    public bool supporting { get; set; }
    }
    //----------------------
    public class YahooObjectSchema
    {
        public string busObId { get; set; }
        public BsaFd[] fieldDefinitions  { get; set; }
        //public fieldDefinitions[] BsaFd { get; set; }
        //public List<fieldDefinitions> BsaFd { get; set; }
        public string firstRecIdField { get; set; }
        //public gridDefinitions[] BsaGd { get; set; }
        public string name { get; set; }
        public string recIdFields { get; set; }
        //public relationships[] BsaR { get; set; }
        public string stateFieldId { get; set; }
        public string states { get; set; }
        public string errorCode { get; set; }
        public string errorMessage { get; set; }
        public bool hasError { get; set; }
        public string httpStatusCode { get; set; }
    }

    public class BsaFd 
    {
      public bool autoFill { get; set; }
      public bool calculated { get; set; }
      public string category { get; set; }
      public int decimalDigits { get; set; }
      public string description { get; set; }
      public string details { get; set; }
      public string displayName { get; set; }
      public bool enabled { get; set; }
      public string fieldId { get; set; }
      public bool hasDate { get; set; }
      public bool hasTime { get; set; }
      public bool isFullTextSearchable { get; set; }
      public string maximumSize { get; set; }
      public string name { get; set; }
      public bool readOnly { get; set; }
      public bool required { get; set; }
      public string type { get; set; }
      public string typeLocalized { get; set; }
      public bool validated { get; set; }
      public int wholeDigits { get; set; }
    }

    public class gridDefinitions
    {
      public string gridId { get; set; }
      public string name { get; set; }
      public string displayName { get; set; }
    }

    public class relationships
    {
      public string cardinality { get; set; }
      public string description { get; set; }
      public string displayName { get; set; }
      //public fieldDefinitions[] rFd { get; set; }
      public BsaFd[] rFd { get; set; }
      public string relationshipId { get; set; }
      public string target { get; set; }
    }



    //---------------------------------------
    public class RstResult
    {
        public RstBo[] YahooObjects { get; set; }
        public bool hasPrompts { get; set; }
        public RstLink[] links { get; set; }
        //public prompts[]
        //public searchResultsFields[]
        public RstSimpleResults simpleResults { get; set; }

        public int totalRows { get; set; }
        public string errorCode { get; set; }
        public string errorMessage { get; set; }
        public bool hasError { get; set; }
    }
    public class RstSimpleResults
    {
        public RstGroups[] groups { get; set; }
        public string title { get; set; }
        public string errorCode { get; set; }
        public string errorMessage { get; set; }
        public bool hasError { get; set; }
    }

    public class RstGroups
    {
        public bool isBusObTarget { get; set; }
        public RstSimpleResultsItems[] simpleResultsListItems { get; set; }
        public string subTitle { get; set; }
        public string targetId { get; set; }
        public string title { get; set; }
        public string errorCode { get; set; }
        public string errorMessage { get; set; }
        public bool hasError { get; set; }
    }
    public class RstSimpleResultsItems
    {
        public string busObId { get; set; }
        public string busObRecId { get; set; }
        public string docRepositoryItemId { get; set; }
        public string galleryImage { get; set; }
        public RstLink[] links { get; set; }
        public int publicId { get; set; }
        public string scope { get; set; }
        public string scopeOwner { get; set; }
        public string subTitle { get; set; }
        public string text { get; set; }
        public string title { get; set; }
    }
    //-------------------------------------------
    public class RstBo
    {

        public string busObId { get; set; }
        public string busObPublicId { get; set; }
        public string busObRecId { get; set; }
        public RstField[] fields { get; set; }
        public RstLink[] links { get; set; }
        public string errorCode { get; set; }
        public string errorMessage { get; set; }
        public bool hasError { get; set; }

    }

    public class RstField
    {

        public bool dirty { get; set; }
        public string displayName { get; set; }
        public string fieldId { get; set; }
        public string html { get; set; }
        public string name { get; set; }
        public string value { get; set; }
    }

    public class RstLink
    {
        public string name { get; set; }
        public string url { get; set; }
    }


    public class TokenResult
    {
        public string access_token { get; set; }
        public string token_type { get; set; }
        public int expires_in { get; set; }
        public string refresh_token { get; set; }
        public string as_client_id { get; set; } //as:client
        public string username { get; set; }
        public string issued { get; set; } //.issued
        public string expires { get; set; } //.expires
    }
    public class TokenError
    {
        public string error { get; set; }
        public string error_description { get; set; }
    }
}

