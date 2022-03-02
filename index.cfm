

<!--- Keep track of some internal performance monitoring --->
<cfset request.monitor_perf_times = structnew()>
<cfset request.monitor_perf_time_stamps = structnew()>

<cfparam name="url.lock_info" default="false">
<cfparam name="url.show_user" default="true">
<cfparam name="url.show_all_processes" default="false">

<cfinclude template="udfs.cfm">
<cfparam name="session.last_refresh" default="#now()#">
<cfparam name="session.last_spid_cpu" default="#structnew()#">

<cfparam name="session.server" default="your_DSN_name">
<cfif isdefined("url.server") and len(trim(url.server))>
	<cfset session.server = url.server>
</cfif>
<cfset sqlserver = session.server>

<cfset clock_in("Entire Page")>

<cfinclude template="get_logins_today.cfm">

<cfsetting showdebugoutput="No">


<cfset session.spid_cpu = structnew()><!--- Used to determine change in CPU --->
<cfset seefusion_servers = structnew()>
<cfset seefusion_servers["10.10.0.204"] = "http://10.10.0.204:8999/xml">
<cfset seefusion_servers["10.10.0.200"] = "http://10.10.0.200:8999/xml">
<cfset seefusion_servers["10.10.0.214"] = "http://10.10.0.214:8999/xml">
<cfset seefusion_servers["10.10.0.195"] = "http://10.10.0.195:8999/xml">
<cfset seefusion_servers["10.10.0.220"] = "http://10.10.0.220:8999/xml">


<cfset seefusion_servers_xml = structnew()>
<!--- These have to be defined when setting their value
	with bracket notation. --->
<cfloop collection="#seefusion_servers#" item="i">
	<cfset structinsert(seefusion_servers_xml,i,"")>
</cfloop>

<cfif isdefined("url.kill") and val(url.kill)>
	<cfquery name="kill_it" datasource="#session.server#">
		kill #val(url.kill)#
	</cfquery>
	<cflocation url="index.cfm">
</cfif>

<cfset clock_in("Get Main Query")>
<cfquery name="qry_running_statements" datasource="#session.server#">
	select  
		substring(st.text, (req.statement_start_offset/2) + 1,
			( (
			case req.statement_end_offset
				when -1 then datalength(st.text)
				else req.statement_end_offset
			end - req.statement_start_offset)/2) + 1) as current_statement,
	(req.statement_start_offset/2) + 1 as statement_start,
	--((case req.statement_end_offset when -1 then datalength(st.text)	else req.statement_end_offset	end - req.statement_start_offset)/2) + 1 as statement_length,
	req.blocking_session_id,
	sess.session_id,
	isnull(req.total_elapsed_time,0) as total_elapsed_time,
	isnull(req.percent_complete,0) as percent_complete,
	db.name,
	sess.host_name,
	sess.login_name,
	sess.program_name,
	isnull(req.cpu_time,0) as cpu_time,
	isnull(req.status,sess.status) as status,
	req.last_wait_type,
	conn.client_net_address,
	sess.row_count,
	st.text,
	req.command,
	req.request_id,
	req.open_transaction_count,
	req.open_resultset_count,
	case when program_name like 'SQLAgent - TSQL JobStep%' THEN 
		(select name from 
		msdb.dbo.sysjobs WITH(NOLOCK)
		where job_id = 
		substring(program_name,38,2) 
		+ substring(program_name,36,2) 
		+ substring(program_name,34,2) 
		+ substring(program_name,32,2) + '-' 
		+ substring(program_name,42,2)
		+ substring(program_name,40,2) + '-' 
		+ substring(program_name,46,2)
		+ substring(program_name,44,2)  + '-'
		+ substring(program_name,48,4)  + '-'
		+ substring(program_name,52,12)) ELSE '' END as job_name,
	req.plan_handle
	from sys.dm_exec_sessions sess with(nolock)
	left outer join sys.dm_exec_requests req with(nolock) on sess.session_id	= req.session_id
	left outer join sys.databases db with(nolock) on req.database_id = db.database_id
	left outer join sys.dm_exec_connections	conn with(nolock) on req.connection_id = conn.connection_id
	outer apply sys.dm_exec_sql_text(req.sql_handle) as st
--	left outer join sys.dm_exec_cached_plans plans with(nolock) on req.plan_handle = plans.plan_handle
--	left outer join sys.database_principals	princ with(nolock) on req.user_id = princ.principal_id	
--	left outer join sys.dm_tran_active_transactions trans with(nolock) on req.transaction_id = trans.transaction_id
--	outer apply sys.dm_exec_query_plan(req.plan_handle)	
	--outer apply sys.dm_exec_plan_attributes(req.plan_handle)
	where isnull(req.session_id,0)  <> @@spid
	<cfif not show_all_processes>
		and (st.text is not null or exists(	select 1 
											from sys.dm_exec_requests req2 with(nolock) 
											where req2.blocking_session_id = sess.session_id))
	</cfif>
	order by req.total_elapsed_time desc
</cfquery>
<cfset clock_out("Get Main Query")>
<cfif url.lock_info>
	<cfset clock_in("Get Lock Query")>
	<cfquery name="qry_lock_info" datasource="#session.server#">
		select 	convert (smallint, req_spid) As spid,
			rsc_dbid As dbid,
			db.name As database_name,
			rsc_objid As ObjId,
			rsc_indid As IndId,
			substring (v.name, 1, 4) As Type,
			substring (rsc_text, 1, 32) as Resource,
			substring (u.name, 1, 8) As Mode,
			substring (x.name, 1, 5) As Status
		
		from master.dbo.syslockinfo lock with(nolock)
		INNER JOIN master.dbo.spt_values v with(nolock) on lock.rsc_type = v.number
				and v.type = 'LR'
		INNER JOIN master.dbo.spt_values x with(nolock) on lock.req_status = x.number
				and x.type = 'LS'
		INNER JOIN master.dbo.spt_values u with(nolock) on lock.req_mode + 1 = u.number
				and u.type = 'L'
		INNER JOIN master.dbo.sysdatabases db on lock.rsc_dbid = db.dbid
	</cfquery>
	<cfset clock_out("Get Lock Query")>
</cfif>

<!--- <cfset qry_running_statements.blocking_session_id[2] = qry_running_statements.session_id[1]> --->

<html>
	<head>
		<title>Server Monitor</title>
		<style>
			.general_text
				{
					font-size: x-small;
					font-weight: normal;
				}
			.alt_row
				{
					background: #E2E2E2;
				}
			.smaller_text
				{
					font-size: xx-small;
					font-weight: normal;
				}
			.sql_statement
				{
					font-size: x-small;
				}
			.sql_command
				{
					font-size: 12pt;
				}
			.icon
				{
					cursor: 'hand';
				}
		</style>
		<script language="javascript" type="text/javascript" src="js/progress_bar.js"></script>
	</head>
	<body bgcolor="lightgrey">
	
		<cfquery name="non_blocked_spids" dbtype="query">
			SELECT session_id
			FROM qry_running_statements
			WHERE blocking_session_id = 0
				<cfif qry_running_statements.recordcount gt 1>
					or blocking_session_id not in (<cfloop query="qry_running_statements">#session_id#,</cfloop>123456)
				</cfif>
		</cfquery>
		
		<cfoutput>
		<table class="displaytable" cellpadding="0" cellspacing="0" border="0" width="100%">
        	<tr>
        		<td width="1%" nowrap>
					<h3>
						#qry_running_statements.recordcount# 
						<cfif not show_all_processes>
							request#iif(qry_running_statements.recordcount eq 1,de(""),de("s"))# running.
						<cfelse>
							process#iif(qry_running_statements.recordcount eq 1,de(""),de("es"))#.
						</cfif>
						&nbsp;&nbsp;
					</h3>
				</td>
				<td width="1%" nowrap>
					<select id="server" name="server">
						<option value="your_DSN_name"<cfif session.server eq "your_DSN_name"> selected</cfif>>your_DSN_name</option>
					</select>&nbsp;&nbsp;
				</td>
				<td width="1%" nowrap>
					<input type="checkbox" name="lock_info" id="lock_info" value="1"<cfif url.lock_info> checked</cfif>><label for="lock_info" class="smaller_text">&nbsp;Show Extended Lock Info</label><br>
					<input type="checkbox" name="show_user" id="show_user" value="1"<cfif url.show_user> checked</cfif>><label for="show_user" class="smaller_text">&nbsp;Show Logged In User</label><br>
					<input type="checkbox" name="show_all_processes" id="show_all_processes" value="1"<cfif url.show_all_processes> checked</cfif>><label for="show_all_processes" class="smaller_text">&nbsp;Show All Processes</label>
				</td>
				<td align="left" nowrap>
					&nbsp;&nbsp;
					<button type="button" onclick="window.location.href='index.cfm?server=' + document.getElementById('server').value + '&lock_info=' + document.getElementById('lock_info').checked + '&show_user=' + document.getElementById('show_user').checked + '&show_all_processes=' + document.getElementById('show_all_processes').checked;">Refresh</button>
				</td>
        		<td align="right">
					#dateformat(now(),"mm/dd/yyyy")# #timeformat(now(),"hh:mm:ss")#
				</td>
        	</tr>
        </table>
			
			<table cellpadding="2" cellspacing="0" border="1" width="100%" class="general_text">
				<cfloop query="non_blocked_spids">
					#output_spid(session_id)#
				</cfloop>
		    </table>
		
			 
			<!---  <cfdump var="#xmlparse(qry_running_statements.query_plan[2])#"> --->
			
		</cfoutput>
		<SCRIPT LANGUAGE="JavaScript" TYPE="text/javascript">
        <!--
            function show_hide_sql(what_to_show,spid)
				{
					document.getElementById('sql_command_' + spid).style.display = (what_to_show == 'command' ? '' : 'none');
					document.getElementById('sql_statement_' + spid).style.display = (what_to_show == 'statement' ? '' : 'none');
					document.getElementById('sql_text_' + spid).style.display = (what_to_show == 'text' ? '' : 'none');
				}
				
            function show_hide_blocking(spid)
				{
					var plus_minus = document.getElementById('plus_minus_' + spid);
					document.getElementById('spids_blocked_by_' + spid).style.display = (plus_minus.innerText == '[ + ]' ? '' : 'none');
					plus_minus.innerText = (plus_minus.innerText == '[ + ]' ? '[ - ]' : '[ + ]');
				}
        //-->
        </SCRIPT>
		<cfset session.last_refresh = now()>
		<cfset session.last_spid_cpu = session.spid_cpu>
		<cfset clock_out("Entire Page")>
		<cfoutput>
			<br>
			<br>
			<div style="font-size: 8pt;">
				<cfloop collection="#request.monitor_perf_times#" item="i">
					#i#: #request.monitor_perf_times[i]/1000# sec<br>
				</cfloop>
			</div>
		</cfoutput>
	</body>
</html>
