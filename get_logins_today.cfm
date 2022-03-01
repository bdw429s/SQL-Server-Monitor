<cfparam name="application.qry_get_logins_timestamp" default="03/31/1980 9:55 pm">

<cfif url.show_user and 0>
	<cfset clock_in("Get Login Query")>
	<cfif not structkeyexists(application,"qry_get_logins") or datediff("n",application.qry_get_logins_timestamp,now()) gt 20>
		
		<cfquery name="application.qry_get_logins" datasource="sqlc5">
			<!--- This only makes sense for a site where the users are logged in and you track who logs in from what IP address 
			Implement a query here that returns the following columns of the day's logins --->
			select distinct
				id,
				ip_address,
				full_name,
				company_name
			from loginTable
			where loginDate > getDate()-1
		</cfquery>
		<cfset application.qry_get_logins_timestamp = now()>
	</cfif>
	<cfset clock_out("Get Login Query")>
<cfelse>
	<cfset application.qry_get_logins = querynew("id,ip_address,full_name,company_name","varchar,varchar,varchar,varchar")>
</cfif>