/*
 * Name: AvayaIfx
 * Created by VC#2008
 * Description: Queries the Informix CMS DB, using a JDBC SQLI driver converted to C# via IKVM.net
 * Compiling: VC#2008 works
 * User: garbla
 * Date: 06/30/19
 * 10/14/19 glb - ACD=1 for at least Skill 64
 * 01/30/20 glb - corrected catch with using
 * 03/11/20 glb - corrected SetEx never finished implementing, just used commands instead
 * 04/25/20 glb - asah zero padding removed
 * 04/30/20 glb - added 264 for L2 folks
 * 07/16/20 glb - added better suspend file
 * 12/17/20 glb - added NOANSREDIR at agent level
 * 12/23/20 glb - added year to day to truncate time and sum for partial_archive
 * 12/26/20 glb - moving from phone-stat to phone-agent-stat and timeout to 120
 * 01/06/21 glb - trimmed phone_stat data
 * 02/03/21 glb - using phauth splits instead of hard coded. Hopefully, adding HIST for all splits might help with html issues
 * 04/29/21 glb - added acl for Anthony
 * TODO FOR AGENT DETAIL
 * TODO UPDATE TO USING FOR MSSQL/SYBASE
 * 
 * CMS doesn't have unique indexes and partial_archive flag is present on dupes. Suspect undocumented column, means to sum block for result.
 * 
 * 
 * USE RELEASE TO PUBLISH
 * 
 * TODO USE PHAUTH LIST OF SPLIT/SKILL CODES INSTEAD OF HARD CODED
 * 
 * partial_archive appears to mean, that a sum must be used to get accurate data. Have seen on 1 time block.
 * 
 * DRDA protocol 
 * https://www.ibm.com/support/knowledgecenter/en/SSGU8G_11.50.0/com.ibm.admin.doc/ids_admin_0206.htm
 * you are using DRDA port vs the SQLI port
 * https://www.tutorialspoint.com/java-connection-the-setclientinfo-method-with-example
 * https://stackoverflow.com/questions/2723735/how-to-remove-all-zeros-from-strings-beginning
 * 
 * Available Fields:
 * Avaya™ Call Management System (CMS) Database Items and Calculations (CMS-DB-Items-database.pdf)
 * 
 * MAXWAITING
 * MAXSTAFFED
 * MAXOCWTIME
 * MAXINQUEUE
 * TODO ADD NOANSREDIR(RONA) FOR SHAWNA
 * TODO ADD OUTFLOWCALLS/INFLOWCALLS/redirectcalls(ROLLED?) select row_date,split,outflowcalls from hsplit where outflowcalls > 0 and row_date > '2018-11-28' and split = 64
 * TODO MOVE TO CWHOURLY AND RUN IT IN TWO 5 MINUTE WINDOWS EVERY MINUTE
 * TODO ADD PARAMETER TO ALLOW BACKFILL DAYS(1 = 1 DAY AGO)
 * 
 * Updates The following Values:
 * HIST::HEARTBEAT
 * HIST::TCH
 * HIST::ABNH
 * HIST::ASAH
 * 
 */
using com.informix.jdbc;
using PHAuthSpace;
using RedisSharp;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
namespace AvayaIfx
{
    class AvayaIfx
    {
        TimeSpan elapsedTime;
        DateTime startTime;
        int totalRecords;
        const int MaxAge = -6; //months don't touch for delete
        const int DaysBack = 7; //7
        const int HistBack = 2; //2
        //const string Splits = "464,864,264,64";
        string Splits;
        const int ACD = 1; //1
        SqlConnection cnn;
    
        PHAuthenticator PhAuth;
        IfxDriver id;
        StringBuilder SqlMerge;

        public AvayaIfx()
        {

            startTime = DateTime.Now;
            id = new IfxDriver();
            Environment.ExitCode = 0;
            totalRecords = 0;

            PhAuth = new PHAuthenticator("LIVE");

            foreach (string desk in PhAuth.SkillList)
            {
                Splits += desk+",";
            }

            if (Splits.Contains(','))
            {
                Splits = Splits.Substring(0, Splits.Length - 1);
            }

            Console.WriteLine("Splits:{0}", Splits);

            SqlMerge = new StringBuilder();
            SqlMerge.Append("MERGE INTO dbo.phone_agent_stat as d USING (select ");
            SqlMerge.Append("@Mtime as mtime, ");
            SqlMerge.Append("@LogId as logid, ");
            SqlMerge.Append("@Split as split, ");
            SqlMerge.Append("@StaffTime as stafftime, ");
            SqlMerge.Append("@AvailTime as availtime, ");
            SqlMerge.Append("@AuxTime as auxtime, ");
            SqlMerge.Append("@AcwOutCalls as acwoutcalls, ");
            SqlMerge.Append("@AcwOutTime as acwouttime, ");
            SqlMerge.Append("@AcwOutOffCalls as acwoutoffcalls, ");
            SqlMerge.Append("@AcwOutOffTime as acwoutofftime, ");
            SqlMerge.Append("@AcdCalls as acdcalls, ");
            SqlMerge.Append("@AcdTime as AcdTime, ");
            SqlMerge.Append("@AcwTime as AcwTime, ");
            SqlMerge.Append("@Transferred as transferred, ");
            SqlMerge.Append("@AbnCalls as abncalls, ");
            SqlMerge.Append("@AbnTime as abntime, ");
            SqlMerge.Append("@IringTime as iringtime, ");
            SqlMerge.Append("@RingCalls as ringcalls, ");
            SqlMerge.Append("@RingTime as ringtime, ");
            SqlMerge.Append("@AnsRingTime as ansringtime, ");
            SqlMerge.Append("@OtherTime as othertime, ");
            SqlMerge.Append("@AuxTime0 as auxtime0, ");
            SqlMerge.Append("@AuxTime1 as auxtime1, ");
            SqlMerge.Append("@AuxTime2 as auxtime2, ");
            SqlMerge.Append("@AuxTime3 as auxtime3, ");
            SqlMerge.Append("@AuxTime4 as auxtime4, ");
            SqlMerge.Append("@AuxTime5 as auxtime5, ");
            SqlMerge.Append("@AuxTime6 as auxtime6, ");
            SqlMerge.Append("@AuxTime7 as auxtime7, ");
            SqlMerge.Append("@AuxTime8 as auxtime8, ");
            SqlMerge.Append("@AuxTime9 as auxtime9, ");
            SqlMerge.Append("@NoAnsRedir as noansredir, ");
            SqlMerge.Append("@MaxQueue as maxqueue, ");
            SqlMerge.Append("@MaxAgent as maxagent, ");
            SqlMerge.Append("@MaxOcw as maxocw, ");
            SqlMerge.Append("@AnsTime as anstime, ");
            SqlMerge.Append("@AbnRing as abnring, ");
            SqlMerge.Append("@Desk as desk ");
            SqlMerge.Append(") as s ");
            SqlMerge.Append("ON (psa_date = mtime and psa_split = split and psa_agent=logid) ");
            SqlMerge.Append("WHEN MATCHED THEN UPDATE SET psa_stafftime=stafftime,psa_availtime=availtime,psa_acwoutcalls=acwoutcalls,psa_acwouttime=acwouttime,psa_acwoutoffcalls=acwoutoffcalls,psa_acwoutofftime=acwoutofftime,psa_acdcalls=acdcalls,psa_acdtime=acdtime,psa_acwtime=acwtime,psa_transferred=transferred,psa_abncalls=abncalls,psa_abntime=abntime,psa_iringtime=iringtime,psa_ringcalls=ringcalls,psa_ringtime=ringtime,psa_ansringtime=ansringtime,psa_othertime=othertime,psa_auxtime=auxtime,psa_auxtime0=auxtime0,psa_auxtime1=auxtime1,psa_auxtime2=auxtime2,psa_auxtime3=auxtime3,psa_auxtime4=auxtime4,psa_auxtime5=auxtime5,psa_auxtime6=auxtime6,psa_auxtime7=auxtime7,psa_auxtime8=auxtime8,psa_auxtime9=auxtime9,psa_noansredir = noansredir,psa_maxqueue=maxqueue,psa_maxagent=maxagent,psa_maxocw=maxocw,psa_anstime=anstime,psa_abnring = abnring,psa_desk=desk ");
            SqlMerge.Append("WHEN NOT MATCHED THEN INSERT ");
            SqlMerge.Append("(psa_date,psa_split,psa_agent,psa_stafftime,psa_availtime,psa_acwoutcalls,psa_acwouttime,psa_acwoutoffcalls,psa_acwoutofftime,psa_acdcalls,psa_acdtime,psa_acwtime,psa_transferred,psa_abncalls,psa_abntime,psa_iringtime,psa_ringcalls,psa_ringtime,psa_ansringtime,psa_othertime,psa_auxtime,psa_auxtime0,psa_auxtime1,psa_auxtime2,psa_auxtime3,psa_auxtime4,psa_auxtime5,psa_auxtime6,psa_auxtime7,psa_auxtime8,psa_auxtime9,psa_noansredir,psa_maxqueue,psa_maxagent,psa_maxocw,psa_anstime,psa_abnring,psa_desk) ");
            SqlMerge.Append(" VALUES ");
            SqlMerge.Append("(mtime,split,logid,stafftime,availtime,acwoutcalls,acwouttime,acwoutoffcalls,acwoutofftime,acdcalls,acdtime,acwtime,transferred,abncalls,abntime,iringtime,ringcalls,ringtime,ansringtime,othertime,auxtime,auxtime0,auxtime1,auxtime2,auxtime3,auxtime4,auxtime5,auxtime6,auxtime7,auxtime8,auxtime9,noansredir,maxqueue,maxagent,maxocw,anstime,abnring,desk); ");

            Console.WriteLine("Start: {0}", DateTime.Now);
            Console.WriteLine("W#:" + Environment.MachineName);
            if (PhAuth.ExitOnSuspendFile())
            {
                Environment.ExitCode = 1;
                Console.WriteLine("Found Suspend File Bye\n");
                PhAuth.LogMessage(System.AppDomain.CurrentDomain.FriendlyName, "Found Suspend File, Bye");
                System.Environment.Exit(1);
            }

            Console.WriteLine("Environ:" + PhAuth.GetEnvironment());
            PhAuth.PrunePhone();
            PhAuth.LogMessage(System.AppDomain.CurrentDomain.FriendlyName, "Start");
        }
        static void Main(string[] args)
        {
            var dd = new AvayaIfx();
            dd.RunIt();
        }
        public void RunIt()
        {
            cnn = new SqlConnection(PhAuth.GetSQLString());
            cnn.Open();

            
            PhAuth.safeSetTextDb(string.Format("EXE:{0}:HEARTBEAT", System.AppDomain.CurrentDomain.FriendlyName.ToUpper().Replace(".EXE", "")), DateTime.Now.ToString(), PhAuth.RedisRealTime);

            try
            {

                var pp = new java.util.Properties();
                pp.put("USER", PhAuth.GetAvayaCMSUser());
                pp.put("PASSWORD", PhAuth.GetAvayaCMSPassword());
                java.sql.Connection sc = id.connect(PhAuth.GetAvayaJavaURL(), pp); // returns java.sql.Connection
                
                java.sql.Statement js = sc.createStatement();
                js.setQueryTimeout(120); // 60 isn't enough
                //Agent Details Splunk in half hour buckets
                java.sql.ResultSet rs = js.executeQuery(String.Format("select to_char(row_date,'%Y-%m-%d')|| ' ' || left(lpad(starttime,4,'0000'),2) || ':' || right(lpad(starttime,4,'0000'),2) as mtime,logid,split,sum(acdcalls) as acdcalls,sum(acdtime) as acdtime,sum(abncalls) as abncalls,sum(abntime) as abntime,sum(ti_stafftime) as ti_stafftime,sum(ti_availtime) as ti_availtime,sum(acwoutcalls) as acwoutcalls,sum(acwouttime) as acwouttime,sum(acwoutoffcalls) as acwoutoffcalls,sum(acwoutofftime) as acwoutofftime,sum(acwtime) as acwtime,sum(ringcalls) as ringcalls,sum(ringtime) as ringtime,sum(i_ringtime) as i_ringtime,sum(ansringtime) as ansringtime,sum(transferred) as transferred,sum(ti_othertime) as ti_othertime,sum(ti_auxtime) as ti_auxtime,sum(ti_auxtime0) as ti_auxtime0,sum(ti_auxtime1) as ti_auxtime1,sum(ti_auxtime2) as ti_auxtime2,sum(ti_auxtime3) as ti_auxtime3,sum(ti_auxtime4) as ti_auxtime4,sum(ti_auxtime5) as ti_auxtime5,sum(ti_auxtime6) as ti_auxtime6,sum(ti_auxtime7) as ti_auxtime7,sum(ti_auxtime8) as ti_auxtime8,sum(ti_auxtime9) as ti_auxtime9,sum(noansredir) as noansredir from hagent where split in ({0}) and row_date >= (current YEAR TO DAY - {1} UNITS DAY) and acd={2} group by mtime,split,logid;",Splits,DaysBack,ACD));
                while (rs.next())
                {
                    using (SqlCommand sqlCmd = new SqlCommand(SqlMerge.ToString(), cnn))
                    {
                        Console.WriteLine("HAGENT Date: {0}", rs.getString("mtime"));
                        sqlCmd.Parameters.Add("@Mtime", SqlDbType.VarChar).Value = rs.getString("mtime");
                        sqlCmd.Parameters.Add("@LogId", SqlDbType.VarChar).Value = rs.getString("logid");
                        sqlCmd.Parameters.Add("@Split", SqlDbType.VarChar).Value = rs.getString("split");
                        sqlCmd.Parameters.Add("@StaffTime", SqlDbType.VarChar).Value = rs.getString("ti_stafftime");
                        sqlCmd.Parameters.Add("@AvailTime", SqlDbType.VarChar).Value = rs.getString("ti_availtime");
                        sqlCmd.Parameters.Add("@AuxTime", SqlDbType.VarChar).Value = rs.getString("ti_auxtime");
                        sqlCmd.Parameters.Add("@AcwOutCalls", SqlDbType.VarChar).Value = rs.getString("acwoutcalls");
                        sqlCmd.Parameters.Add("@AcwOutTime", SqlDbType.VarChar).Value = rs.getString("acwouttime");
                        sqlCmd.Parameters.Add("@AcwOutOffCalls", SqlDbType.VarChar).Value = rs.getString("acwoutoffcalls");
                        sqlCmd.Parameters.Add("@AcwOutOffTime", SqlDbType.VarChar).Value = rs.getString("acwoutofftime");
                        sqlCmd.Parameters.Add("@AcdCalls", SqlDbType.VarChar).Value = rs.getString("acdcalls");
                        sqlCmd.Parameters.Add("@AcdTime", SqlDbType.VarChar).Value = rs.getString("acdtime");
                        sqlCmd.Parameters.Add("@AcwTime", SqlDbType.VarChar).Value = rs.getString("acwtime");
                        sqlCmd.Parameters.Add("@Transferred", SqlDbType.VarChar).Value = rs.getString("transferred");
                        sqlCmd.Parameters.Add("@AbnCalls", SqlDbType.VarChar).Value = rs.getString("abncalls");
                        sqlCmd.Parameters.Add("@AbnTime", SqlDbType.VarChar).Value = rs.getString("abntime");
                        sqlCmd.Parameters.Add("@IringTime", SqlDbType.VarChar).Value = rs.getString("i_ringtime");
                        sqlCmd.Parameters.Add("@RingCalls", SqlDbType.VarChar).Value = rs.getString("ringcalls");
                        sqlCmd.Parameters.Add("@RingTime", SqlDbType.VarChar).Value = rs.getString("ringtime");
                        sqlCmd.Parameters.Add("@AnsRingTime", SqlDbType.VarChar).Value = rs.getString("ansringtime");
                        sqlCmd.Parameters.Add("@OtherTime", SqlDbType.VarChar).Value = rs.getString("ti_othertime");
                        sqlCmd.Parameters.Add("@AuxTime0", SqlDbType.VarChar).Value = rs.getString("ti_auxtime0");
                        sqlCmd.Parameters.Add("@AuxTime1", SqlDbType.VarChar).Value = rs.getString("ti_auxtime1");
                        sqlCmd.Parameters.Add("@AuxTime2", SqlDbType.VarChar).Value = rs.getString("ti_auxtime2");
                        sqlCmd.Parameters.Add("@AuxTime3", SqlDbType.VarChar).Value = rs.getString("ti_auxtime3");
                        sqlCmd.Parameters.Add("@AuxTime4", SqlDbType.VarChar).Value = rs.getString("ti_auxtime4");
                        sqlCmd.Parameters.Add("@AuxTime5", SqlDbType.VarChar).Value = rs.getString("ti_auxtime5");
                        sqlCmd.Parameters.Add("@AuxTime6", SqlDbType.VarChar).Value = rs.getString("ti_auxtime6");
                        sqlCmd.Parameters.Add("@AuxTime7", SqlDbType.VarChar).Value = rs.getString("ti_auxtime7");
                        sqlCmd.Parameters.Add("@AuxTime8", SqlDbType.VarChar).Value = rs.getString("ti_auxtime8");
                        sqlCmd.Parameters.Add("@AuxTime9", SqlDbType.VarChar).Value = rs.getString("ti_auxtime9");
                        sqlCmd.Parameters.Add("@NoAnsRedir", SqlDbType.VarChar).Value = rs.getString("noansredir");
                        sqlCmd.Parameters.Add("@MaxQueue", SqlDbType.VarChar).Value = "0";
                        sqlCmd.Parameters.Add("@MaxAgent", SqlDbType.VarChar).Value = "0";
                        sqlCmd.Parameters.Add("@MaxOcw", SqlDbType.VarChar).Value = "0";
                        sqlCmd.Parameters.Add("@AnsTime", SqlDbType.VarChar).Value = "0";
                        sqlCmd.Parameters.Add("@AbnRing", SqlDbType.VarChar).Value = "0";
                        sqlCmd.Parameters.Add("@Desk", SqlDbType.VarChar).Value = PhAuth.Skill2Long(rs.getString("split"));

                        
                        sqlCmd.ExecuteNonQuery();
                        sqlCmd.Dispose();
                    }
                    if (PhAuth.ExitOnSuspendFile())
                    {
                        Environment.ExitCode = 1;
                        Console.WriteLine("Found Suspend File, Bye\n");
                        PhAuth.LogMessage(System.AppDomain.CurrentDomain.FriendlyName, "Found Suspend File, Bye");
                        System.Environment.Exit(1);
                    }
                }
                if (!rs.isClosed())
                {
                    rs.close();
                }


                //hsplit CSV, half hour buckets
                rs = js.executeQuery(String.Format("select split,to_char(row_date,'%Y-%m-%d') || ' ' || left(lpad(starttime,4,'0000'),2) || ':' ||right(lpad(starttime,4,'0000'),2) as rtime, sum(acdcalls) as acdcalls,sum(abncalls) as totabncalls, sum(abnringcalls) as abnringcalls,sum(transferred) as transferred,max(maxinqueue) as maxinqueue,max(maxstaffed) as maxstaffed,max(maxocwtime) as maxocwtime,sum(acwtime) as acwtime,sum(acdtime) as acdtime,sum(anstime) as anstime,sum(abntime) as abntime,sum(i_stafftime) as i_stafftime,sum(i_availtime) as i_availtime,sum(i_auxtime) as i_auxtime,sum(acwoutcalls) as acwoutcalls,sum(acwouttime) as acwouttime,sum(acwoutoffcalls) as acwoutoffcalls,sum(acwoutofftime) as acwoutofftime,sum(acdtime) as acdtime, sum(acwtime) as acwtime,sum(transferred) as transferred,sum(abntime) as abntime,sum(i_ringtime) as i_ringtime,sum(ringcalls) as ringcalls,sum(ringtime) as ringtime,sum(anstime) as ansringtime,sum(i_othertime) as i_othertime,sum(i_auxtime0) as i_auxtime0, sum(i_auxtime1) as i_auxtime1, sum(i_auxtime2) as i_auxtime2, sum(i_auxtime3) as i_auxtime3, sum(i_auxtime4) as i_auxtime4, sum(i_auxtime5) as i_auxtime5, sum(i_auxtime6) as i_auxtime6, sum(i_auxtime7) as i_auxtime7, sum(i_auxtime8) as i_auxtime8, sum(i_auxtime9) as i_auxtime9,sum(noansredir) as noansredir from hsplit where split in ({0}) and row_date >= (current YEAR TO DAY - {1} UNITS DAY) and acd ={2} group by rtime,split;", Splits, DaysBack, ACD));
                while (rs.next())
                {
                    totalRecords++;
                    Console.WriteLine("hsplit Rec #{0}", totalRecords);

                    using (SqlCommand sqlCmd = new SqlCommand(SqlMerge.ToString(), cnn))
                    {
                        Console.WriteLine("HSPLIT Date: {0}", rs.getString("rtime"));
                        sqlCmd.Parameters.Add("@Mtime", SqlDbType.VarChar).Value = rs.getString("rtime");
                        sqlCmd.Parameters.Add("@LogId", SqlDbType.VarChar).Value = rs.getString("split");
                        sqlCmd.Parameters.Add("@Split", SqlDbType.VarChar).Value = rs.getString("split");
                        sqlCmd.Parameters.Add("@AcdCalls", SqlDbType.VarChar).Value = rs.getString("acdcalls");
                        sqlCmd.Parameters.Add("@AbnCalls", SqlDbType.VarChar).Value = rs.getString("totabncalls");//abncalls
                        sqlCmd.Parameters.Add("@StaffTime", SqlDbType.VarChar).Value = rs.getString("i_stafftime");
                        sqlCmd.Parameters.Add("@AvailTime", SqlDbType.VarChar).Value = rs.getString("i_availtime");
                        sqlCmd.Parameters.Add("@AuxTime", SqlDbType.VarChar).Value = rs.getString("i_auxtime");
                        sqlCmd.Parameters.Add("@AcwOutCalls", SqlDbType.VarChar).Value = rs.getString("acwoutcalls");
                        sqlCmd.Parameters.Add("@AcwOutTime", SqlDbType.VarChar).Value = rs.getString("acwouttime");
                        sqlCmd.Parameters.Add("@AcwOutOffCalls", SqlDbType.VarChar).Value = rs.getString("acwoutoffcalls");
                        sqlCmd.Parameters.Add("@AcwOutOffTime", SqlDbType.VarChar).Value = rs.getString("acwoutofftime");
                        sqlCmd.Parameters.Add("@AcdTime", SqlDbType.VarChar).Value = rs.getString("acdtime");
                        sqlCmd.Parameters.Add("@AcwTime", SqlDbType.VarChar).Value = rs.getString("acwtime");
                        sqlCmd.Parameters.Add("@Transferred", SqlDbType.VarChar).Value = rs.getString("transferred");
                        sqlCmd.Parameters.Add("@AbnTime", SqlDbType.VarChar).Value = rs.getString("abntime");
                        sqlCmd.Parameters.Add("@IringTime", SqlDbType.VarChar).Value = rs.getString("i_ringtime");
                        sqlCmd.Parameters.Add("@RingCalls", SqlDbType.VarChar).Value = rs.getString("ringcalls");
                        sqlCmd.Parameters.Add("@RingTime", SqlDbType.VarChar).Value = rs.getString("ringtime");
                        sqlCmd.Parameters.Add("@AnsRingTime", SqlDbType.VarChar).Value = rs.getString("ansringtime");

                        sqlCmd.Parameters.Add("@OtherTime", SqlDbType.VarChar).Value = rs.getString("i_othertime");
                        sqlCmd.Parameters.Add("@AuxTime0", SqlDbType.VarChar).Value = rs.getString("i_auxtime0");
                        sqlCmd.Parameters.Add("@AuxTime1", SqlDbType.VarChar).Value = rs.getString("i_auxtime1");
                        sqlCmd.Parameters.Add("@AuxTime2", SqlDbType.VarChar).Value = rs.getString("i_auxtime2");
                        sqlCmd.Parameters.Add("@AuxTime3", SqlDbType.VarChar).Value = rs.getString("i_auxtime3");
                        sqlCmd.Parameters.Add("@AuxTime4", SqlDbType.VarChar).Value = rs.getString("i_auxtime4");
                        sqlCmd.Parameters.Add("@AuxTime5", SqlDbType.VarChar).Value = rs.getString("i_auxtime5");
                        sqlCmd.Parameters.Add("@AuxTime6", SqlDbType.VarChar).Value = rs.getString("i_auxtime6");
                        sqlCmd.Parameters.Add("@AuxTime7", SqlDbType.VarChar).Value = rs.getString("i_auxtime7");
                        sqlCmd.Parameters.Add("@AuxTime8", SqlDbType.VarChar).Value = rs.getString("i_auxtime8");
                        sqlCmd.Parameters.Add("@AuxTime9", SqlDbType.VarChar).Value = rs.getString("i_auxtime9");
                        sqlCmd.Parameters.Add("@NoAnsRedir", SqlDbType.VarChar).Value = rs.getString("noansredir");
                        sqlCmd.Parameters.Add("@MaxQueue", SqlDbType.VarChar).Value = rs.getString("maxinqueue");
                        sqlCmd.Parameters.Add("@MaxAgent", SqlDbType.VarChar).Value = rs.getString("maxstaffed");
                        sqlCmd.Parameters.Add("@MaxOcw", SqlDbType.VarChar).Value = rs.getString("maxocwtime");
                        sqlCmd.Parameters.Add("@AnsTime", SqlDbType.VarChar).Value = rs.getString("anstime");
                        sqlCmd.Parameters.Add("@AbnRing", SqlDbType.VarChar).Value = rs.getString("abnringcalls");
                        sqlCmd.Parameters.Add("@Desk", SqlDbType.VarChar).Value = PhAuth.Skill2Long(rs.getString("split"));
                        sqlCmd.ExecuteNonQuery();
                        sqlCmd.Dispose();
                    }

                    if (PhAuth.ExitOnSuspendFile())
                    {
                        Environment.ExitCode = 1;
                        Console.WriteLine("Found Suspend File, Bye\n");
                        PhAuth.LogMessage(System.AppDomain.CurrentDomain.FriendlyName, "Found Suspend File, Bye");
                        System.Environment.Exit(1);
                    }
                }
                if (!rs.isClosed())
                {
                    rs.close();
                }



                using (SqlCommand sqlCmd = new SqlCommand(@"select psa_split,sum(psa_abncalls) as psa_abncalls,sum(psa_acdcalls) as psa_acdcalls,sum(psa_anstime) as psa_anstime, (case when sum(psa_acdcalls) > 0 then sum(psa_anstime)/sum(psa_acdcalls) else 0 end) as psa_asa, (case when sum(psa_acdcalls) > 0 then sum(psa_acdtime)/sum(psa_acdcalls) else 0 end) as psa_acl from dbo.phone_agent_stat with (nolock) where psa_split=psa_agent and cast(convert(char(11), psa_date, 113) as datetime ) = cast(convert(char(11), getdate(), 113) as datetime ) group by psa_split;", cnn))
                {
                    TimeSpan SecTime;
                    DateTime dateTime;
                    SqlDataReader sqlReader = sqlCmd.ExecuteReader();
                    while (sqlReader.Read())
                    {
                        Console.WriteLine("psa_split#:{0}",sqlReader["psa_split"]);
                        PhAuth.safeSetTextDb(string.Format("HIST:{0}:ABNH", PhAuth.Skill2Long(sqlReader["psa_split"].ToString()).ToString()),sqlReader["psa_abncalls"].ToString(),PhAuth.RedisHistTime);
                        PhAuth.safeSetTextDb(string.Format("HIST:{0}:TCH", PhAuth.Skill2Long(sqlReader["psa_split"].ToString()).ToString()), sqlReader["psa_acdcalls"].ToString(), PhAuth.RedisHistTime);

                        SecTime = TimeSpan.FromSeconds(Convert.ToDouble(sqlReader["psa_asa"].ToString()));
                        dateTime = DateTime.Today.Add(SecTime);
                        dateTime.ToString("mm:ss");
                        PhAuth.safeSetTextDb(string.Format("HIST:{0}:ASAH", PhAuth.Skill2Long(sqlReader["psa_split"].ToString()).ToString()), dateTime.ToString("mm:ss").Replace("00:", ":").Replace(":00", "0"), PhAuth.RedisHistTime);


                        //For Executive Dash in Cherwell needed by Anthony
                        SecTime = TimeSpan.FromSeconds(Convert.ToDouble(sqlReader["psa_acl"].ToString()));
                        dateTime = DateTime.Today.Add(SecTime);
                        dateTime.ToString("mm:ss");
                        PhAuth.safeSetTextDb(string.Format("HIST:{0}:ACL", PhAuth.Skill2Long(sqlReader["psa_split"].ToString()).ToString()), dateTime.ToString("mm:ss").Replace("00:", ":").Replace(":00", "0"), PhAuth.RedisHistTime);

                        totalRecords++;
                    }
                    sqlReader.Close();
                    sqlCmd.Dispose();
                }

                //Trim stats
                using (SqlCommand sqlCmd = new SqlCommand(@"delete from dbo.phone_agent_stat where DATEADD(month,@MaxAge,GETDATE()) > psa_date;", cnn))
                {
                    Console.WriteLine("Trimming dbo.phone_agent_stat");
                    sqlCmd.CommandTimeout = 120;
                    sqlCmd.Parameters.Add("@MaxAge", SqlDbType.Int).Value = MaxAge;
                    sqlCmd.ExecuteNonQuery();
                    sqlCmd.Dispose();
                }

                Environment.ExitCode = 0;
                if (!sc.isClosed())
                {
                    sc.close();
                }

            }

            catch (SqlException _sex)
            {
                Console.WriteLine(_sex.Message);
                Environment.ExitCode = 1;
                PhAuth.LogMessage(System.AppDomain.CurrentDomain.FriendlyName, "SQL Error:" + _sex.Message);
                Console.WriteLine("SQL Error:" + _sex.Message);
            }
            catch (Exception _ex)
            {
                Console.WriteLine("ERROR" + _ex.Message);
                Environment.ExitCode = 1;
                PhAuth.LogMessage(System.AppDomain.CurrentDomain.FriendlyName, "Error:" + _ex.Message);
            }
            finally
            {
#if DEBUG
                Console.WriteLine("Debug Sleeping");
                Thread.Sleep(10000);
#endif

                // Make sure we are logged out and disconnected. Put inside a finally block so that the code will be executed even
                // if an exception is thrown
                if (cnn != null && cnn.State != System.Data.ConnectionState.Closed)
                {
                    cnn.Close();
                }
                elapsedTime = DateTime.Now - startTime;
                Console.WriteLine("Records:" + totalRecords.ToString("D2"));
                Console.WriteLine("Elapsed Seconds:" + elapsedTime.TotalSeconds.ToString());
                Console.WriteLine("Records/Seconds:" + totalRecords / elapsedTime.TotalSeconds);
                Console.WriteLine("End: {0}", DateTime.Now);
                PhAuth.LogMessage(System.AppDomain.CurrentDomain.FriendlyName, "End Exit:" + Environment.ExitCode.ToString() + " Records:" + totalRecords.ToString());

            }

        }

    }
}

