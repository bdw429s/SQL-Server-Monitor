<!--- <cfdump var="#url.plan_handle#"><br> --->
<!--- <cfdump var="#session.server#"><br> --->
<cfquery name="q" datasource="#session.server#">
SELECT query_plan FROM sys.dm_exec_query_plan(#url.plan_handle#)
</cfquery>
<cfif q.RecordCount eq 1>
	<cfheader 
	    name="content-disposition" 
	    value="attachment; filename=myFile.sqlplan"
	    charset="utf-8">
	<cfcontent 
	    type="application/octet-stream" 
	    variable="#CharsetDecode(q.query_plan, 'utf-8')#">    
<cfelse>
	<cfdump var="#q#">	
</cfif>

