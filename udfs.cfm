


<cffunction name="output_spid">
	<cfargument name="spid">
	<cfsavecontent variable="return_output">
		<cfquery name="this_spid" dbtype="query">
			SELECT *
			FROM qry_running_statements
			WHERE session_id = #spid#
		</cfquery>
		<cfquery name="blocked_spids" dbtype="query">
			SELECT *
			FROM qry_running_statements
			WHERE blocking_session_id = #session_id#
		</cfquery>
		<cfoutput query="this_spid">
			<tr>
				<td nowrap="nowrap" valign="top" width="1%">
					<strong>#session_id#</strong>&nbsp;
					<a href="javascript: window.location.href='index.cfm?kill=#session_id#';"><img src="images/kill.gif" width="16" height="16" alt="" border="0" onclick="return confirm('Do you wish to kill spid #session_id#?');"></a>
					<cfset structinsert(session.spid_cpu,session_id,cpu_time,true)>	
					<cfif Len(plan_handle) gt 0>
						<br><a href="query_plan.cfm?plan_handle=0x#BinaryEncode(plan_handle, 'Hex')#">Show Plan</a>
					</cfif>
					<br>cpu: #cpu_time#
					<!--- If the last cpu numbers are within 5 minutes, and this spid was around back then --->
					<cfset seconds_since_last_load = datediff("s",session.last_refresh,now())>
					<cfif seconds_since_last_load lt 300 and seconds_since_last_load gt 0 and structkeyexists(session.last_spid_cpu,session_id)>
						<cfset delta_cpu = cpu_time - session.last_spid_cpu[session_id]>
						<cfif delta_cpu gt 0>
							&nbsp;(^#delta_cpu# / #int(evaluate(seconds_since_last_load/60))#:#evaluate(seconds_since_last_load mod 60)#)
						</cfif>
					</cfif>				
					<br>#status#<cfif status eq "suspended">&nbsp;<span class="icon" onclick="alert('#jsstringformat(last_wait_type_description(last_wait_type))#');" title="#htmleditformat(last_wait_type_description(last_wait_type))#">(#last_wait_type#)</span></cfif><br>
					<cfset days = int(evaluate(total_elapsed_time/86400000))>
					<!--- <cfset hours = int(evaluate(total_elapsed_time/3600000))> --->
					<cfset hours = int(evaluate(total_elapsed_time/3600000)-(days*24))>
					<cfset minutes = int(evaluate(total_elapsed_time/60000)-((hours*60)+(days*1440)))>
					<cfset partial_minute = (total_elapsed_time/1000) mod 60>
					<em>
						<cfif days>#days# Days</cfif>
						<cfif hours>#hours# Hr</cfif>
						<cfif minutes>#minutes# Min</cfif>
						#partial_minute# sec<br>
					</em>
					<cfloop from="1" to="#days#" step="1" index="i">
						<img src="images/day.gif" alt="" border="0" width="35" height="35">
						<cfif i mod 4 eq 0 or (i eq days and days mod 4 lt 4)><br></cfif>
					</cfloop>
					<cfloop from="1" to="#hours#" step="1" index="i">
						<img src="images/1_hour.gif" width="25" height="25" alt="" border="0">
						<cfif i mod 5 eq 0 or (i eq hours and hours mod 5 lt 5)><br></cfif>
					</cfloop>
					<cfloop from="1" to="#minutes#" step="1" index="i">
						<img src="images/100_perc.gif" width="16" height="15" alt="" border="0">
						<cfif i mod 5 eq 0><br></cfif>
					</cfloop>
					<cfif partial_minute lte 12>
						<img src="images/12_perc.gif" width="16" height="15" alt="" border="0">
					<cfelseif partial_minute lte 25>
						<img src="images/25_perc.gif" width="16" height="15" alt="" border="0">
					<cfelseif partial_minute lte 37>
						<img src="images/37_perc.gif" width="16" height="15" alt="" border="0">
					<cfelseif partial_minute lte 50>
						<img src="images/50_perc.gif" width="16" height="15" alt="" border="0">
					<cfelseif partial_minute lte 62>
						<img src="images/62_perc.gif" width="16" height="15" alt="" border="0">
					<cfelseif partial_minute lte 75>
						<img src="images/75_perc.gif" width="16" height="15" alt="" border="0">
					<cfelseif partial_minute lte 81>
						<img src="images/87_perc.gif" width="16" height="15" alt="" border="0">
					</cfif>
					<cfif percent_complete neq "0.0">
						<br><div id="progress_complete"></div>
						<SCRIPT LANGUAGE="JavaScript" TYPE="text/javascript">
						    var myProgBar = new progressBar(
								'progress_complete',	// id of holder element
								2,         //border thickness
								'##000000', //border colour
								'lightgrey', //background colour
								'blue', //bar colour
								'images/bar.jpg', //background image
								'images/back_bar.jpg', //bar image
								'black', // percent dark color
								'white', // percent light color
								150,       //width of bar (excluding border)
								15,        //height of bar (excluding border)
								1          //direction of progress: 1 = right, 2 = down, 3 = left, 4 = up
							);
							myProgBar.setBar(#evaluate(percent_complete/100)#,true);
	                             </SCRIPT>
						<!---  #percent_complete#% Complete --->
					</cfif>
					
					<cfif url.lock_info>
						<cfquery name="qry_locks_by_this_spid" dbtype="query">
                        	SELECT database_name, type, mode, status, ObjId, count(1) as number_of_obj_locks
                        	FROM qry_lock_info
                        	WHERE spid = #val(session_id)#
							GROUP BY database_name, type, mode, status, ObjId
							ORDER BY database_name, ObjId, type, mode, status
                        </cfquery>
						<cfif qry_locks_by_this_spid.recordcount>
							<br>					
							<fieldset><legend>Lock Info</legend>
								<table cellpadding="3" cellspacing="0" border="0" class="smaller_text">
                                	<tr style="font-weight: bold;">
                                		<td>Object</td>
                                		<td>Type</td>
                                		<td>Mode</td>
                                		<td>Status</td>
                                	</tr>
									<cfloop query="qry_locks_by_this_spid">
									
										<cfset clock_in("Get Lock Objects Query")>
										<cfquery name="qry_lock_object_info" datasource="#session.server#">
											select case when xtype = 'C' THEN 'CHECK constraint'
													when  xtype = 'D' THEN 'DEFAULT constraint'
													when  xtype = 'F' THEN 'FOREIGN KEY constraint'
													when  xtype = 'L' THEN 'Log'
													when  xtype = 'FN' THEN 'Scalar function'
													when  xtype = 'IF' THEN 'Inlined table-function'
													when  xtype = 'P' THEN 'Stored procedure'
													when  xtype = 'PK' THEN 'PRIMARY KEY'
													when  xtype = 'RF' THEN 'Replication filter stored procedure'
													when  xtype = 'S' THEN 'System table'
													when  xtype = 'TF' THEN 'Table function'
													when  xtype = 'TR' THEN 'Trigger'
													when  xtype = 'U' THEN 'User table'
													when  xtype = 'UQ' THEN 'UNIQUE constraint'
													when  xtype = 'V' THEN 'View'
													when  xtype = 'X' THEN 'Extended stored procedure' END as obj_type,
												name
											from #qry_locks_by_this_spid.database_name#.dbo.sysobjects with(nolock)
											where id = '#qry_locks_by_this_spid.ObjId#'
										</cfquery>
										<cfset clock_out("Get Lock Objects Query")>
										
	                                	<tr<cfif qry_locks_by_this_spid.currentrow mod 2 neq 0> class="alt_row"</cfif>>
	                                		<td nowrap<cfif number_of_obj_locks gt 1> title="This spid has #number_of_obj_locks# locks of this type, mode, and status on this object.  Condensed for readability"</cfif><cfif number_of_obj_locks gt 15> style="color: red;"</cfif>>
												#qry_locks_by_this_spid.database_name#<cfif qry_lock_object_info.recordcount>.#rereplacenocase(qry_lock_object_info.name,"_{5,}","_","all")# (#qry_lock_object_info.obj_type#)</cfif>
												<cfif number_of_obj_locks gt 1>
													<span style="font-weight: bold; color: red;">
														&nbsp;#number_of_obj_locks#
													</span>
												</cfif>
											</td>
	                                		<td nowrap>#show_lock_type(qry_locks_by_this_spid.type)#</td>
	                                		<td nowrap>#show_lock_mode(qry_locks_by_this_spid.mode)#</td>
	                                		<td nowrap>#show_lock_status(qry_locks_by_this_spid.status)#</td>
	                                	</tr>
									</cfloop>
                                </table>
							</fieldset>
							<br>
						</cfif>
					</cfif>
				</td>
				<td nowrap="nowrap" valign="top" width="1%">
					<cfif listfindnocase("entity_sts,nations_history,nations_stats,entity,nations,nations_document",name) and not listfindnocase("NTS\SQLservice,webusernations,webusernls,pbtempest,webuserdime",login_name)>
						<cfset flag_it = true>
					<cfelse>
						<cfset flag_it = false>
					</cfif>
					<span <cfif flag_it>style="color:red"</cfif>>
						DB: #name#
					</span>
					<cfif structkeyexists(seefusion_servers,host_name)>
						#output_web_server_info(host_name,session_id)#
					<cfelse>
						<cfif len(trim(host_name))><br>#host_name#</cfif>
						<span <cfif flag_it>style="color:red"</cfif>>
							<br>#login_name#
						</span>
					</cfif>
					<cfif len(trim(program_name))>
						<cfif len(trim(job_name))>
							<br>#job_name#
						<cfelse>
							<br>#program_name#
						</cfif>
					</cfif>
					<cfif trim(client_net_address) neq trim(host_name)><br>#htmleditformat(client_net_address)#</cfif>
					<cfif val(open_transaction_count)><br>#open_transaction_count# Open Transaction#iif(open_transaction_count eq 1,de(""),de("s"))#</cfif>
					<cfif val(open_resultset_count)><br>#open_resultset_count# Open ResultSet#iif(open_resultset_count eq 1,de(""),de("s"))#</cfif>
					<cfif val(row_count)><br>#row_count# Row#iif(row_count eq 1,de(""),de("s"))#<!---  Returned To Client ---></cfif>
				</td>
	    		<td class="sql_statement" valign="top">
					<cfif len(trim(text))>
						<button onclick="show_hide_sql('command',#session_id#)" type="button">Command</button>
						<button onclick="show_hide_sql('statement',#session_id#)" type="button">Statement</button>
						<cfif current_statement neq text><button  onclick="show_hide_sql('text',#session_id#)"type="button">Full Text</button></cfif><br>
						<!--- #statement_start#<br>
						#statement_length#<br> --->
						<cfset current_statement_formatted = sql_color_code(htmleditformat(current_statement))>
						<div id="sql_command_#session_id#" class="sql_command">#command#</div>
						<div id="sql_statement_#session_id#" style="display: none;">#current_statement_formatted#</div>
						<div id="sql_text_#session_id#" style="display: none;">
							<!--- #sql_color_code(htmleditformat(mid(text,1,statement_start-1)))# --->
							<cfset statement_front = htmleditformat(mid(text,1,statement_start-1))>
							<cfset statement_front = replacenocase(statement_front,lf,"<br>#crlf#","all")>
							<cfset statement_front = replacenocase(statement_front,"	","&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;","all")>
							#statement_front#
							<div style="background: ##FFF7B3;">#current_statement_formatted#</div>
							<!--- #sql_color_code(htmleditformat(mid(text,statement_start+statement_length,len(text))))# --->
							<cfset statement_back= htmleditformat(mid(text,statement_start+len(current_statement),len(text)))>
							<cfset statement_back = replacenocase(statement_back,lf,"<br>#crlf#","all")>
							<cfset statement_back = replacenocase(statement_back,"	","&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;","all")>
							#statement_back#
						</div>
					<cfelse>
						AWAITING COMMAND
					</cfif>
				</td>
	    	</tr>
			<cfif blocked_spids.recordcount>
				<tr>
					<td colspan="3" align="left" class="icon" style="color:red; fond-size: 14pt; background: ##FFDDDD;" onclick="show_hide_blocking(#session_id#);">
						<strong><span id="plus_minus_#session_id#">[ + ]</span> Blocking #blocked_spids.recordcount# spid#iif(blocked_spids.recordcount eq 1,de(""),de("s"))#</strong>
					</td>
				</tr>
				<tr id="spids_blocked_by_#session_id#" style="display:none;">
					<td colspan="3" align="right" style="background: ##FFDDDD;">
						<table cellpadding="0" style="background: lightgrey;" cellspacing="0" border="1" width="97%" class="general_text">
							<cfloop query="blocked_spids">
								#output_spid(session_id)#
							</cfloop>
					    </table>
					</td>
				</tr>
			</cfif>
		</cfoutput>
	</cfsavecontent>
	<cfreturn return_output>
</cffunction>


<cffunction name="output_web_server_info">
	<cfargument name="server_ip" type="string">
	<cfargument name="spid" type="string">
	<cfset clock_in("SeeFusion API")>
	<cfif issimplevalue(seefusion_servers_xml[server_ip])>
		<cftry>
			<cfhttp url="#seefusion_servers[server_ip]#" method="GET" result="foo"></cfhttp>
			<cfset server_xml = xmlparse(foo.FileContent)>	
			<cfset seefusion_servers_xml[server_ip] = structnew()>
			<cfset seefusion_servers_xml[server_ip].name = server_xml.seefusioninfo.server.name>
			<cfset seefusion_servers_xml[server_ip].arr_running_requests = xmlsearch(server_xml,"seefusioninfo/server/runningRequests/page")>
			<cfcatch>
				<cfdump var="#cfcatch.message#">
				<cfreturn "<br>" & host_name>
			</cfcatch>
		</cftry>
	</cfif>
	<cfset this_arr_running_requests = seefusion_servers_xml[server_ip].arr_running_requests>
	
	<cfset return_value = "<br>" & seefusion_servers_xml[server_ip].name.XmlText>
	<cfloop from="1" to="#arraylen(this_arr_running_requests)#" step="1" index="i">
		<cfset this_page = this_arr_running_requests[i]>
		<cfif isdefined("this_page.query")
			and findnocase("SPID=#spid#, Server=#sqlserver#}",this_page.query.sql.XmlText)>
			<cfquery name="qry_get_this_login" dbtype="query">
              	SELECT *
              	FROM application.qry_get_logins
              	WHERE ip_address = '#this_page.ip.XmlText#'
              </cfquery>
			 <cfif qry_get_this_login.recordcount>
				<cfset return_value = return_value & "<br><span class=""icon"" onclick=""window.open('http://yoursite.com/index.cfm/contacts/view&id=" & qry_get_this_login.id & "','entity_detail','height=600,width=800,resizable=yes,toolbar=no');"" title=""Click to View Detail""><u>" & trim(qry_get_this_login.full_name) & " - " & trim(qry_get_this_login.company_name) & "</u></span>">
			 <cfelse>
				<cfset return_value = return_value & "<br>" & this_page.ip.XmlText>
			 </cfif>
			<cfset return_value = return_value & "<br><span onclick=""alert('" & jsstringformat(this_page.url.XmlText) & "');"" class=""icon"" title=""" & htmleditformat(this_page.url.XmlText) & """><u>Click for URL</u></span>">
			<cfbreak>
		</cfif>
	</cfloop>
	<cfset clock_out("SeeFusion API")>
	<cfreturn return_value>
</cffunction>

<cfscript>


	function sql_color_code(sql_string)
		{
			clock_in("SQL Color Coding");
			color_definition = structnew();
			color_definition["Character string"]  = "Red";
 			color_definition["Stored Procedure"] = '##AF0000'; // Dark Red
			color_definition["System Table"] = 'Green';
			color_definition["Comment"] = '##008000'; // Dark Green
			color_definition["System Function"] = 'Magenta';
			color_definition["Keyword"] = 'Blue';
			color_definition["Operator"] = 'Gray';
			
			operator_list = "!|,|.|/|*|-|+|<|>|(|)|=";
			reserved_word_list = "OUTPUT|ADD|EXCEPT|PERCENT|ALL|EXEC|PLAN|ALTER|EXECUTE|PRECISION|AND|EXISTS|PRIMARY|ANY|EXIT|PRINT|AS|FETCH|PROC|ASC|FILE|PROCEDURE|AUTHORIZATION|FILLFACTOR|PUBLIC|BACKUP|FOR|RAISERROR|BEGIN|FOREIGN|READ|BETWEEN|FREETEXT|READTEXT|BREAK|FREETEXTTABLE|RECONFIGURE|BROWSE|FROM|REFERENCES|BULK|FULL|REPLICATION|BY|FUNCTION|RESTORE|CASCADE|GOTO|RESTRICT|CASE|GRANT|RETURN|CHECK|GROUP|REVOKE|CHECKPOINT|HAVING|RIGHT|CLOSE|HOLDLOCK|ROLLBACK|CLUSTERED|IDENTITY|ROWCOUNT|COALESCE|IDENTITY_INSERT|ROWGUIDCOL|COLLATE|IDENTITYCOL|RULE|COLUMN|IF|SAVE|COMMIT|IN|SCHEMA|COMPUTE|INDEX|SELECT|CONSTRAINT|INNER|SESSION_USER|CONTAINS|INSERT|SET|CONTAINSTABLE|INTERSECT|SETUSER|CONTINUE|INTO|SHUTDOWN|CONVERT|IS|SOME|CREATE|JOIN|STATISTICS|CROSS|KEY|SYSTEM_USER|CURRENT|KILL|TABLE|CURRENT_DATE|LEFT|TEXTSIZE|CURRENT_TIME|LIKE|THEN|CURRENT_TIMESTAMP|LINENO|TO|CURRENT_USER|LOAD|TOP|CURSOR|NATIONAL|TRAN|DATABASE|NOCHECK|TRANSACTION|DBCC|NONCLUSTERED|TRIGGER|DEALLOCATE|NOT|TRUNCATE|DECLARE|NULL|TSEQUAL|DEFAULT|NULLIF|UNION|DELETE|OF|UNIQUE|DENY|OFF|UPDATE|DESC|OFFSETS|UPDATETEXT|DISK|ON|USE|DISTINCT|OPEN|USER|DISTRIBUTED|OPENDATASOURCE|VALUES|DOUBLE|OPENQUERY|VARYING|DROP|OPENROWSET|VIEW|DUMMY|OPENXML|WAITFOR|DUMP|OPTION|WHEN|ELSE|OR|WHERE|END|ORDER|WHILE|ERRLVL|OUTER|WITH|ESCAPE|OVER|WRITETEXT";
			system_stored_proc_list = "sp_ActiveDirectory_Obj|sp_ActiveDirectory_SCP|sp_column_privileges|sp_special_columns|sp_columns|sp_sproc_columns|sp_databases|sp_statistics|sp_fkeys|sp_stored_procedures|sp_pkeys|sp_table_privileges|sp_server_info|sp_tables|sp_cursor_list|sp_describe_cursor_columns|sp_describe_cursor|sp_describe_cursor_tables|sp_add_maintenance_plan|sp_delete_maintenance_plan_db|sp_add_maintenance_plan_db|sp_delete_maintenance_plan_job|sp_add_maintenance_plan_job|sp_help_maintenance_plan|sp_delete_maintenance_plan|sp_addlinkedserver|sp_indexes|sp_addlinkedsrvlogin|sp_linkedservers|sp_catalogs|sp_primarykeys|sp_column_privileges_ex|sp_serveroption|sp_columns_ex|sp_table_privileges_ex|sp_droplinkedsrvlogin|sp_tables_ex|sp_foreignkeys|sp_fulltext_catalog|sp_help_fulltext_catalogs_cursor|sp_fulltext_column|sp_help_fulltext_columns|sp_fulltext_database|sp_help_fulltext_columns_cursor|sp_fulltext_service|sp_help_fulltext_tables|sp_fulltext_table|sp_help_fulltext_tables_cursor|sp_help_fulltext_catalogs|sp_add_log_shipping_database|sp_delete_log_shipping_database|sp_add_log_shipping_plan|sp_delete_log_shipping_plan|sp_add_log_shipping_plan_database|sp_delete_log_shipping_plan_database|sp_add_log_shipping_primary|sp_delete_log_shipping_primary|sp_add_log_shipping_secondary|sp_delete_log_shipping_secondary|sp_can_tlog_be_applied|sp_get_log_shipping_monitor_info|sp_change_monitor_role|sp_remove_log_shipping_monitor|sp_change_primary_role|sp_resolve_logins|sp_change_secondary_role|sp_update_log_shipping_monitor_info|sp_create_log_shipping_monitor_account|sp_update_log_shipping_plan|sp_define_log_shipping_monitor|sp_update_log_shipping_plan_database|sp_OACreate|sp_OAMethod|sp_OADestroy|sp_OASetProperty|sp_OAGetErrorInfo|sp_OAStop|sp_OAGetPropertyObjectHierarchySyntax|sp_add_agent_parameter|sp_enableagentoffload|sp_add_agent_profile|sp_enumcustomresolvers|sp_addarticle|sp_enumdsn|sp_adddistpublisher|sp_enumfullsubscribers|sp_adddistributiondb|sp_expired_subscription_cleanup|sp_adddistributor|sp_generatefilters|sp_addmergealternatepublisher|sp_getagentoffloadinfo|sp_addmergearticle|sp_getmergedeletetype|sp_addmergefilter|sp_get_distributor|sp_addmergepublication|sp_getqueuedrows|sp_addmergepullsubscription|sp_getsubscriptiondtspackagename|sp_addmergepullsubscription_agent|sp_grant_publication_access|sp_addmergesubscription|sp_help_agent_default|sp_addpublication|sp_help_agent_parameter|sp_addpublication_snapshot|sp_help_agent_profile|sp_addpublisher70|sp_helparticle|sp_addpullsubscription|sp_helparticlecolumns|sp_addpullsubscription_agent|sp_helparticledts|sp_addscriptexec|sp_helpdistpublisher|sp_addsubscriber|sp_helpdistributiondb|sp_addsubscriber_schedule|sp_helpdistributor|sp_addsubscription|sp_helpmergealternatepublisher|sp_addsynctriggers|sp_helpmergearticle|sp_addtabletocontents|sp_helpmergearticlecolumn|sp_adjustpublisheridentityrange|sp_helpmergearticleconflicts|sp_article_validation|sp_helpmergeconflictrows|sp_articlecolumn|sp_helpmergedeleteconflictrows|sp_articlefilter|sp_helpmergefilter|sp_articlesynctranprocs|sp_helpmergepublication|sp_articleview|sp_helpmergepullsubscription|sp_attachsubscription|sp_helpmergesubscription|sp_browsesnapshotfolder|sp_helppublication|sp_browsemergesnapshotfolder|sp_help_publication_access|sp_browsereplcmds|sp_helppullsubscription|sp_change_agent_parameter|sp_helpreplfailovermode|sp_change_agent_profile|sp_helpreplicationdboption|sp_changearticle|sp_helpreplicationoption|sp_changedistpublisher|sp_helpsubscriberinfo|sp_changedistributiondb|sp_helpsubscription|sp_changedistributor_password|sp_helpsubscription_properties|sp_changedistributor_property|sp_ivindexhasnullcols|sp_changemergearticle|sp_link_publication|sp_changemergefilter|sp_marksubscriptionvalidation|sp_changemergepublication|sp_mergearticlecolumn|sp_changemergepullsubscription|sp_mergecleanupmetadata|sp_changemergesubscription|sp_mergedummyupdate|sp_changepublication|sp_mergesubscription_cleanup|sp_changesubscriber|sp_publication_validation|sp_changesubscriber_schedule|sp_refreshsubscriptions|sp_changesubscriptiondtsinfo|sp_reinitmergepullsubscription|sp_changesubstatus|sp_reinitmergesubscription|sp_change_subscription_properties|sp_reinitpullsubscription|sp_check_for_sync_trigger|sp_reinitsubscription|sp_copymergesnapshot|sp_removedbreplication|sp_copysnapshot|sp_repladdcolumn|sp_copysubscription|sp_replcmds|sp_deletemergeconflictrow|sp_replcounters|sp_disableagentoffload|sp_repldone|sp_drop_agent_parameter|sp_repldropcolumn|sp_drop_agent_profile|sp_replflush|sp_droparticle|sp_replicationdboption|sp_dropanonymouseagent|sp_replication_agent_checkup|sp_dropdistpublisher|sp_replqueuemonitor|sp_dropdistributiondb|sp_replsetoriginator|sp_dropmergealternatepublisher|sp_replshowcmds|sp_dropdistributor|sp_repltrans|sp_dropmergearticle|sp_restoredbreplication|sp_dropmergefilter|sp_resyncmergesubscription|sp_revoke_publication_access|sp_dropmergepublication|sp_scriptsubconflicttable|sp_dropmergepullsubscription|sp_script_synctran_commands|sp_setreplfailovermode|sp_dropmergesubscription|sp_showrowreplicainfo|sp_droppublication|sp_subscription_cleanup|sp_droppullsubscription|sp_table_validation|sp_dropsubscriber|sp_update_agent_profile|sp_dropsubscription|sp_validatemergepublication|sp_dsninfo|sp_validatemergesubscription|sp_dumpparamcmd|sp_vupgrade_replication|sp_addalias|sp_droprolemember|sp_addapprole|sp_dropserver|sp_addgroup|sp_dropsrvrolemember|sp_addlinkedsrvlogin|sp_dropuser|sp_addlogin|sp_grantdbaccess|sp_addremotelogin|sp_grantlogin|sp_addrole|sp_helpdbfixedrole|sp_addrolemember|sp_helpgroup|sp_addserver|sp_helplinkedsrvlogin|sp_addsrvrolemember|sp_helplogins|sp_adduser|sp_helpntgroup|sp_approlepassword|sp_helpremotelogin|sp_changedbowner|sp_helprole|sp_changegroup|sp_helprolemember|sp_changeobjectowner|sp_helprotect|sp_change_users_login|sp_helpsrvrole|sp_dbfixedrolepermission|sp_helpsrvrolemember|sp_defaultdb|sp_helpuser|sp_defaultlanguage|sp_MShasdbaccess|sp_denylogin|sp_password|sp_dropalias|sp_remoteoption|sp_dropapprole|sp_revokedbaccess|sp_dropgroup|sp_revokelogin|sp_droplinkedsrvlogin|sp_setapprole|sp_droplogin|sp_srvrolepermission|sp_dropremotelogin|sp_validatelogins|sp_droprole|sp_processmail|xp_sendmail|xp_deletemail|xp_startmail|xp_findnextmsg|xp_stopmail|xp_readmail|sp_trace_create|sp_trace_setfilter|sp_trace_generateevent|sp_trace_setstatus|sp_trace_setevent|sp_add_alert|sp_help_jobhistory|sp_add_category|sp_help_jobschedule|sp_add_job|sp_help_jobserver|sp_add_jobschedule|sp_help_jobstep|sp_add_jobserver|sp_help_notification|sp_add_jobstep|sp_help_operator|sp_add_notification|sp_help_targetserver|sp_add_operator|sp_help_targetservergroup|sp_add_targetservergroup|sp_helptask|sp_add_targetsvrgrp_member|sp_manage_jobs_by_login|sp_addtask|sp_msx_defect|sp_apply_job_to_targets|sp_msx_enlist|sp_delete_alert|sp_post_msx_operation|sp_delete_category|sp_purgehistory|sp_delete_job|sp_purge_jobhistory|sp_delete_jobschedule|sp_reassigntask|sp_delete_jobserver|sp_remove_job_from_targets|sp_delete_jobstep|sp_resync_targetserver|sp_delete_notification|sp_start_job|sp_delete_operator|sp_stop_job|sp_delete_targetserver|sp_update_alert|sp_delete_targetservergroup|sp_update_category|sp_delete_targetsvrgrp_member|sp_update_job|sp_droptask|sp_update_jobschedule|sp_help_alert|sp_update_jobstep|sp_help_category|sp_update_notification|sp_help_downloadlist|sp_update_operator|sp_helphistory|sp_update_targetservergroup|sp_help_job|sp_updatetask|xp_sqlagent_proxy_account|sp_add_data_file_recover_suspect_db|sp_helpconstraint|sp_addextendedproc|sp_helpdb|sp_addextendedproperty|sp_helpdevice|sp_add_log_file_recover_suspect_db|sp_helpextendedproc|sp_addmessage|sp_helpfile|sp_addtype|sp_helpfilegroup|sp_addumpdevice|sp_helpindex|sp_altermessage|sp_helplanguage|sp_autostats|sp_helpserver|sp_attach_db|sp_helpsort|sp_attach_single_file_db|sp_helpstats|sp_bindefault|sp_helptext|sp_bindrule|sp_helptrigger|sp_bindsession|sp_indexoption|sp_certify_removable|sp_invalidate_textptr|sp_configure|sp_lock|sp_create_removable|sp_monitor|sp_createstats|sp_procoption|sp_cycle_errorlog|sp_recompile|sp_datatype_info|sp_refreshview|sp_dbcmptlevel|sp_releaseapplock|sp_dboption|sp_rename|sp_dbremove|sp_renamedb|sp_delete_backuphistory|sp_resetstatus|sp_depends|sp_serveroption|sp_detach_db|sp_setnetname|sp_dropdevice|sp_settriggerorder|sp_dropextendedproc|sp_spaceused|sp_dropextendedproperty|sp_tableoption|sp_dropmessage|sp_unbindefault|sp_droptype|sp_unbindrule|sp_executesql|sp_updateextendedproperty|sp_getapplock|sp_updatestats|sp_getbindtoken|sp_validname|sp_help|sp_who|sp_dropwebtask|sp_makewebtask|sp_enumcodepages|sp_runwebtask|sp_xml_preparedocument|sp_xml_removedocument|xp_cmdshell|xp_logininfo|xp_enumgroups|xp_msver|xp_findnextmsg|xp_revokelogin|xp_grantlogin|xp_sprintf|xp_logevent|xp_sqlmaint|xp_loginconfig|xp_sscanf";
		system_table_list = "sysaltfiles|syslockinfo|syscacheobjects|syslogins|syscharsets|sysmessages|sysconfigures|sysoledbusers|syscurconfigs|sysperfinfo|sysdatabases|sysprocesses|sysdevices|sysremotelogins|syslanguages|sysservers|syscolumns|sysindexkeys|syscomments|sysmembers|sysconstraints|sysobjects|sysdepends|syspermissions|sysfilegroups|sysprotects|sysfiles|sysreferences|sysforeignkeys|systypes|sysfulltextcatalogs|sysusers|sysindexes|sysalerts|sysjobsteps|syscategories|sysnotifications|sysdownloadlist|sysoperators|sysjobhistory|systargetservergroupmembers|sysjobs|systargetservergroups|sysjobschedules|systargetservers|sysjobservers|systaskids|backupfile|restorefile|backupmediafamily|restorefilegroup|backupmediaset|restorehistory|backupset|sysdatabases|sysservers|sysreplicationalerts|MSagent_parameters|Mspublisher_databases|MSagent_profiles|MSreplication_objects|MSarticles|MSreplication_subscriptions|MSdistpublishers|MSrepl_commands|MSdistributiondbs|MSrepl_errors|MSdistribution_agents|MSrepl_originators|MSdistribution_history|MSrepl_transactions|MSdistributor|MSrepl_version|MSlogreader_agents|MSsnapshot_agents|MSlogreader_history|MSsnapshot_history|MSmerge_agents|MSsubscriber_info|MSmerge_history|MSsubscriber_schedule|MSmerge_subscriptions|MSsubscriptions|MSpublication_access|MSsubscription_properties|Mspublications|MSmerge_contents|sysmergearticles|MSmerge_delete_conflicts|sysmergepublications|MSmerge_genhistory|sysmergeschemachange|MSmerge_replinfo|sysmergesubscriptions|MSmerge_tombstone|sysmergesubsetfilters|sysarticles|syspublications|sysarticleupdates|syssubscriptions";
		system_function_list = "AVG|MAX|BINARY_CHECKSUM|MIN|CHECKSUM|SUM|CHECKSUM_AGG|STDEV|COUNT|STDEVP|COUNT_BIG|VAR|GROUPING|VARP|@@DATEFIRST|@@OPTIONS|@@DBTS|@@REMSERVER|@@LANGID|@@SERVERNAME|@@LANGUAGE|@@SERVICENAME|@@LOCK_TIMEOUT|@@SPID|@@MAX_CONNECTIONS|@@TEXTSIZE|@@MAX_PRECISION|@@VERSION|@@NESTLEVEL|@@CURSOR_ROWS|CURSOR_STATUS|@@FETCH_STATUS|DATEADD|DATEDIFF|DATENAME|DATEPART|DAY|GETDATE|GETUTCDATE|MONTH|YEAR|ABS|DEGREES|RAND|ACOS|EXP|ROUND|ASIN|FLOOR|SIGN|ATAN|LOG|SIN|ATN2|LOG10|SQUARE|CEILING|PI|SQRT|COS|POWER|TAN|COT|RADIANS|COL_LENGTH|fn_listextendedproperty|COL_NAME|FULLTEXTCATALOGPROPERTY|COLUMNPROPERTY|FULLTEXTSERVICEPROPERTY|DATABASEPROPERTY|INDEX_COL|DATABASEPROPERTYEX|INDEXKEY_PROPERTY|DB_ID|INDEXPROPERTY|DB_NAME|OBJECT_ID|FILE_ID|OBJECT_NAME|FILE_NAME|OBJECTPROPERTY|FILEGROUP_ID|@@PROCID|FILEGROUP_NAME|SQL_VARIANT_PROPERTY|FILEGROUPPROPERTY|TYPEPROPERTY|FILEPROPERTY|CONTAINSTABLE|FREETEXTTABLE|OPENDATASOURCE|OPENQUERY|OPENROWSET|OPENXML|fn_trace_geteventinfo|IS_SRVROLEMEMBER|fn_trace_getfilterinfo|SUSER_SID|fn_trace_getinfo|SUSER_SNAME|fn_trace_gettable|USER_ID|HAS_DBACCESS|USER|IS_MEMBER|ASCII|NCHAR|SOUNDEX|CHAR|PATINDEX|SPACE|CHARINDEX|REPLACE|STR|DIFFERENCE|QUOTENAME|STUFF|LEFT|REPLICATE|SUBSTRING|LEN|REVERSE|UNICODE|LOWER|RIGHT|UPPER|LTRIM|RTRIM|APP_NAME|CASE|expression|CAST|and|CONVERT|COALESCE|COLLATIONPROPERTY|CURRENT_TIMESTAMP|CURRENT_USER|DATALENGTH|@@ERROR|fn_helpcollations|fn_servershareddrives|fn_virtualfilestats|FORMATMESSAGE|GETANSINULL|HOST_ID|HOST_NAME|IDENT_CURRENT|IDENT_INCR|IDENT_SEED|@@IDENTITY|IDENTITY|(Function)|ISDATE|ISNULL|ISNUMERIC|NEWID|NULLIF|PARSENAME|PERMISSIONS|@@ROWCOUNT|ROWCOUNT_BIG|SCOPE_IDENTITY|SERVERPROPERTY|SESSIONPROPERTY|SESSION_USER|STATS_DATE|SYSTEM_USER|@@TRANCOUNT|USER_NAME|@@CONNECTIONS|@@PACK_RECEIVED|@@CPU_BUSY|@@PACK_SENT|fn_virtualfilestats|@@TIMETICKS|@@IDLE|@@TOTAL_ERRORS|@@IO_BUSY|@@TOTAL_READ|@@PACKET_ERRORS|@@TOTAL_WRITE|PATINDEX|TEXTPTR|TEXTVALID";
		datatype_list = "bigint|decimal|int|numeric|smallint|money|tinyint|smallmoney|bit|float|real|datetime|smalldatetime|char|text|varchar|nchar|ntext|nvarchar|binary|image|varbinary|cursor|timestamp|sql_variant|uniqueidentifier|table|xml";
		unformatted_reserved_word_list = "GO|dbo|ANSI_NULLS|QUOTED_IDENTIFIER|NOLOCK|OUTPUT|ROWLOCK|HOLDLOCK|NOCOUNT";
		
			new_sql_string = "";
			lf = chr(10);
			cr = chr(13);
			crlf = cr & lf;
			
			// replace solitary line feed with a carriage return /  line feed combo
			sql_string = rereplacenocase(sql_string,"([^#cr#])#lf#","\1#crlf#","all");
			sql_string = rereplacenocase(sql_string,"([^#cr#])#lf#","\1#crlf#","all") & " ";
			iterations_to_complete = 0;
			
			// Loop until we are out of text
			while(len(sql_string))
				{
					// Used this for debugging
					// iterations_to_complete = iterations_to_complete + 1; 
					
					// find contiguous whitespace at the start of the string all at once
					// instead of one charater at a time in the main while loop.
					leading_whitespace = refindnocase("^[\s]+(?=\S)",sql_string,1,"yes");
					if(leading_whitespace.len[1])
						{
							this_token = mid(sql_string,leading_whitespace.pos[1],leading_whitespace.len[1]);
							this_formatted_token = this_token;
						}
					// Multi-Line Comment
					else if(mid(sql_string,1,2) eq "/*")
						{
							nested_commend_stack = 1; // We are one comment deep
							pointer = 3; // Start searching immediatley after the opening comment
							// Look for end of comment block being mindful of nested comments
							while(nested_commend_stack and pointer LTE len(sql_string))
								{
									if(mid(sql_string,pointer,2) eq "/*")
										{
											nested_commend_stack = nested_commend_stack + 1; // We entered another level
										}
									else if(mid(sql_string,pointer,2) eq "*/")
										{
											nested_commend_stack = nested_commend_stack - 1; // We exited another level
										}
									pointer = pointer + 1;
								}
								if(nested_commend_stack)
									{
										end_of_comment_block = len(sql_string); // Something went wrong and we ran out of string before we found the ending comment
									}
								else
									{
										end_of_comment_block = pointer; // Pointer is already incremented one extra to allow for two character ending comment
									}

							this_token = mid(sql_string,1,end_of_comment_block);
							this_formatted_token = "<span style=""color:" & color_definition["Comment"] & ";"">" & this_token & "</span>";
						}
					// One Line Comment
					else if(mid(sql_string,1,2) eq "--")
						{
							end_of_line = findnocase(crlf,sql_string,3)+1;
							if(not end_of_line-1)
								{
									end_of_line = len(sql_string);
								}
							this_token = mid(sql_string,1,end_of_line);
							this_formatted_token = "<span style=""color:" & color_definition["Comment"] & ";"">" & this_token & "</span>";
						}
					// Character String
					else if(mid(sql_string,1,1) eq "'")
						{
							end_of_string = findnocase("'",sql_string,2);
							if(not end_of_string)
								{
									end_of_string = len(sql_string);
								}
							this_token = mid(sql_string,1,end_of_string);
							this_formatted_token = "<span style=""color:" & color_definition["Character string"] & ";"">" & this_token & "</span>";
						}
					// Operator
					else if(listfindnocase(operator_list,mid(sql_string,1,1),"|"))
						{
							this_token = mid(sql_string,1,1);
							this_formatted_token = "<span style=""color:" & color_definition["Operator"] & ";"">" & this_token & "</span>";
						}
					else
						{
							// See if there is a word next
							// This may need some work.  I want to find one or more alphanumeric characters plus @ and _
							// at the beginning of the string followed by punctution or whitespace with the exception of @ and _
							// This should catch things like: 
							// SET, ANSI_NULLS, varchar, @executer_entity_id, uniqueidentifier,
							// service_item_type_id, 255, NEWID, NULL, f_date_calc, @@ERROR, sp_executesql
							
							
							search_for_word = refindnocase("^[[:alpha:][:digit:]##@_]+(?=[[:punct:][:space:]^@^_])",sql_string,1,"yes");
							if(search_for_word.len[1])
								{	
									this_token = mid(sql_string,search_for_word.pos[1],search_for_word.len[1]);
									
									// I fear the performance of comparing my token to the "monster lists" so I will weed out as much as possible
									// For performance, catch any numbers, temp tables, table variables and non-colored reserved words here
									if(isnumeric(this_token) or listfindnocase(unformatted_reserved_word_list,this_token,"|") or refindnocase("^##{1,2}|[@].*",this_token))
										{
											this_formatted_token = this_token;
										}
									// Reserved word
									else if(listfindnocase(reserved_word_list,this_token,"|") or listfindnocase(datatype_list,this_token,"|"))
										{
											this_formatted_token = "<span style=""color:" & color_definition["Keyword"] & ";"">" & this_token & "</span>";
										}
									// system function
									else if(listfindnocase(system_function_list,this_token,"|"))
										{
											this_formatted_token = "<span style=""color:" & color_definition["System Function"] & ";"">" & this_token & "</span>";
										}
									// System Table
									else if(listfindnocase(system_table_list,this_token,"|"))
										{
											this_formatted_token = "<span style=""color:" & color_definition["System Table"] & ";"">" & this_token & "</span>";
										}
									// System Stored Proc
									else if(listfindnocase(system_stored_proc_list,this_token,"|"))
										{
											this_formatted_token = "<span style=""color:" & color_definition["Stored Procedure"] & ";"">" & this_token & "</span>";
										}
									// unknown word
									// These should be numbers, user tables, columns, user variables, table variables, and temp tables.
									else
										{
											this_formatted_token = this_token;
										}
								}
							// Catch all-- [ ] # 
							else
								{
									this_token = mid(sql_string,1,1);
									this_formatted_token = this_token;
								}
						}
					// Keep building the new string.
					new_sql_string = new_sql_string & this_formatted_token;
					// Keep slicing off the old string
					sql_string = mid(sql_string,len(this_token)+1,len(sql_string));
				}
			
			// For html display purposes, but in <br> tags and &nbsp;.
			new_sql_string = replacenocase(new_sql_string,crlf,"<br>#crlf#","all");
			new_sql_string = replacenocase(new_sql_string,"	","&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;","all");
			new_sql_string = "<span style=""font-family : 'Courier New'; font-size: 8pt"">" & new_sql_string & "</span>";
			clock_out("SQL Color Coding");
			// Stick a fork in it it's done.
			//writeoutput(iterations_to_complete & " iterations<br>");
			return new_sql_string;
		}
		
		
		function clock_in(what)
			{
				if(not structkeyexists(request.monitor_perf_times,what))
					{
						structinsert(request.monitor_perf_times,what,0);
						structinsert(request.monitor_perf_time_stamps,what,"");
					}
				request.monitor_perf_time_stamps[what] = gettickcount();
			}
			
		function clock_out(what)
			{
				request.monitor_perf_times[what] = request.monitor_perf_times[what] + gettickcount() - request.monitor_perf_time_stamps[what];
			}
			
		function show_lock_type(type)
			{
				var lock_types = structnew();
				
				lock_types['RID'] = 'Lock on a single row in a table identified by a row identifier (RID).';
				lock_types['KEY'] = 'Lock within an index that protects a range of keys in serializable transactions.';
				lock_types['PAG'] = 'Lock on a data or index page.';
				lock_types['EXT'] = 'Lock on an extent';
				lock_types['TAB'] = 'Lock on an entire table, including all data and indexes.';
				lock_types['DB'] = 'Lock on a database.';
				lock_types['FIL'] = 'Lock on a database file.';
				lock_types['APP'] = 'Lock on an application-specified resource.';
				lock_types['MD'] = 'Locks on metadata, or catalog information.';
				lock_types['HBT'] = 'Lock on a heap or B-Tree index.';
				lock_types['AU'] = 'Lock on an allocation unit.';
				
				if(structkeyexists(lock_types,trim(type)))
					{
						return '<span title="#lock_types[type]#">#type#</span>';
					}
				else
					{
						return type;
					}
					
			}
			
			
		function show_lock_mode(mode)
			{
				var lock_modes = structnew();
				
				lock_modes['Sch-S'] = 'Schema stability. Ensures that a schema element, such as a table or index, is not dropped while any session holds a schema stability lock on the schema element.';
				lock_modes['Sch-M'] = 'Schema modification. Must be held by any session that wants to change the schema of the specified resource. Ensures that no other sessions are referencing the indicated object.';
				lock_modes['S'] = 'Shared. The holding session is granted shared access to the resource.';
				lock_modes['U'] = 'Update. Indicates an update lock acquired on resources that may eventually be updated. It is used to prevent a common form of deadlock that occurs when multiple sessions lock resources for potential update at a later time.';
				lock_modes['X'] = 'Exclusive. The holding session is granted exclusive access to the resource.';
				lock_modes['IS'] = 'Intent Shared. Indicates the intention to place S locks on some subordinate resource in the lock hierarchy.';
				lock_modes['IU'] = 'Intent Update. Indicates the intention to place U locks on some subordinate resource in the lock hierarchy.';
				lock_modes['IX'] = 'Intent Exclusive. Indicates the intention to place X locks on some subordinate resource in the lock hierarchy.';
				lock_modes['SIU'] = 'Shared Intent Update. Indicates shared access to a resource with the intent of acquiring update locks on subordinate resources in the lock hierarchy.';
				lock_modes['SIX'] = 'Shared Intent Exclusive. Indicates shared access to a resource with the intent of acquiring exclusive locks on subordinate resources in the lock hierarchy.';
				lock_modes['UIX'] = 'Update Intent Exclusive. Indicates an update lock hold on a resource with the intent of acquiring exclusive locks on subordinate resources in the lock hierarchy.';
				lock_modes['BU'] = 'Bulk Update. Used by bulk operations.';
				lock_modes['RangeS-S'] = 'Shared Key-Range and Shared Resource lock. Indicates serializable range scan.';
				lock_modes['RangeS-U'] = 'Shared Key-Range and Update Resource lock. Indicates serializable update scan.';
				lock_modes['RangeI-N'] = 'Insert Key-Range and Null Resource lock. Used to test ranges before inserting a new key into an index.';
				lock_modes['RangeI-S'] = 'Key-Range Conversion lock. Created by an overlap of RangeI_N and S locks.';
				lock_modes['RangeI-U'] = 'Key-Range Conversion lock created by an overlap of RangeI_N and U locks.';
				lock_modes['RangeI-X'] = 'Key-Range Conversion lock created by an overlap of RangeI_N and X locks.';
				lock_modes['RangeX-S'] = 'Key-Range Conversion lock created by an overlap of RangeI_N and RangeS_S. locks.';
				lock_modes['RangeX-U'] = 'Key-Range Conversion lock created by an overlap of RangeI_N and RangeS_U locks.';
				lock_modes['RangeX-X'] = 'Exclusive Key-Range and Exclusive Resource lock. This is a conversion lock used when updating a key in a range.';

				if(structkeyexists(lock_modes,trim(mode)))
					{
						return '<span title="#lock_modes[mode]#">#mode#</span>';
					}
				else
					{
						return mode;
					}
					
			}			
		function show_lock_status(status)
			{
				var lock_status = structnew();
				
				lock_status['CNVRT'] = 'The lock is being converted from another mode, but the conversion is blocked by another process holding a lock with a conflicting mode.';
				lock_status['GRANT'] = 'The lock was obtained.';
				lock_status['WAIT'] = 'The lock is blocked by another process holding a lock with a conflicting mode.';

				if(structkeyexists(lock_status,trim(status)))
					{
						return '<span title="#lock_status[status]#">#status#</span>';
					}
				else
					{
						return status;
					}
					
			}
			


</cfscript>

<cffunction name="last_wait_type_description">
	<cfargument name="last_wait_type" type="string">
	<cfif last_wait_type eq "ASYNC_DISKPOOL_LOCK">
		<cfreturn "Occurs when there is an attempt to synchronize parallel threads that are performing tasks such as creating or initializing a file.">
	<cfelseif last_wait_type eq "ASYNC_IO_COMPLETION">
		<cfreturn "Occurs when a task is waiting for I/Os to finish.">
	<cfelseif last_wait_type eq "ASYNC_NETWORK_IO">
		<cfreturn "Occurs on network writes when the task is blocked behind the network. Verify that the client is processing data from the server.">
	<cfelseif last_wait_type eq "BACKUP">
		<cfreturn "Occurs when a task is blocked as part of backup processing.">
	<cfelseif last_wait_type eq "BACKUP_CLIENTLOCK">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "BACKUP_OPERATOR">
		<cfreturn "Occurs when a task is waiting for a tape mount. To view the tape status, query sys.dm_io_backup_tapes. If a mount operation is not pending, this wait type may indicate a hardware problem with the tape drive.">
	<cfelseif last_wait_type eq "BACKUPBUFFER">
		<cfreturn "Occurs when a backup task is waiting for data, or is waiting for a buffer in which to store data. This type is not typical, except when a task is waiting for a tape mount.">
	<cfelseif last_wait_type eq "BACKUPIO">
		<cfreturn "Occurs when a backup task is waiting for data, or is waiting for a buffer in which to store data. This type is not typical, except when a task is waiting for a tape mount.">
	<cfelseif last_wait_type eq "BACKUPTHREAD">
		<cfreturn "Occurs when a task is waiting for a backup task to finish. Wait times may be long, from several minutes to several hours. If the task that is being waited on is in an I/O process, this type does not indicate a problem.">
	<cfelseif last_wait_type eq "BAD_PAGE_PROCESS">
		<cfreturn "Occurs when the background suspect page logger is trying to avoid running more than every five seconds. Excessive suspect pages cause the logger to run frequently.">
	<cfelseif last_wait_type eq "BROKER_CONNECTION_RECEIVE_TASK">
		<cfreturn "Occurs when waiting for access to receive a message on a connection endpoint. Receive access to the endpoint is serialized.">
	<cfelseif last_wait_type eq "BROKER_ENDPOINT_STATE_MUTEX">
		<cfreturn "Occurs when there is contention to access the state of a Service Broker connection endpoint. Access to the state for changes is serialized.">
	<cfelseif last_wait_type eq "BROKER_EVENTHANDLER">
		<cfreturn "Occurs when a task is waiting in the primary event handler of the Service Broker. This should occur very briefly.">
	<cfelseif last_wait_type eq "BROKER_INIT">
		<cfreturn "Occurs when initializing Service Broker in each active database. This should occur infrequently.">
	<cfelseif last_wait_type eq "BROKER_MASTERSTART">
		<cfreturn "Occurs when a task is waiting for the primary event handler of the Service Broker to start. This should occur very briefly.">
	<cfelseif last_wait_type eq "BROKER_RECEIVE_WAITFOR">
		<cfreturn "Occurs when the RECEIVE WAITFOR is waiting. This is typical if no messages are ready to be received.">
	<cfelseif last_wait_type eq "BROKER_REGISTERALLENDPOINTS">
		<cfreturn "Occurs during the initialization of a Service Broker connection endpoint. This should occur very briefly.">
	<cfelseif last_wait_type eq "BROKER_SHUTDOWN">
		<cfreturn "Occurs when there is a planned shutdown of Service Broker. This should occur very briefly, if at all.">
	<cfelseif last_wait_type eq "BROKER_TRANSMITTER">
		<cfreturn "Occurs when the Service Broker transmitter is waiting for work.">
	<cfelseif last_wait_type eq "BUILTIN_HASHKEY_MUTEX">
		<cfreturn "May occur after startup of instance, while internal data structures are initializing. Will not recur once data structures have initialized.">
	<cfelseif last_wait_type eq "CHECKPOINT_QUEUE">
		<cfreturn "Occurs while the checkpoint task is waiting for the next checkpoint request.">
	<cfelseif last_wait_type eq "CHKPT">
		<cfreturn "Occurs at server startup to tell the checkpoint thread that it can start.">
	<cfelseif last_wait_type eq "CLR_AUTO_EVENT">
		<cfreturn "Occurs when a task is currently performing common language runtime (CLR) execution and is waiting for a particular autoevent to be initiated.">
	<cfelseif last_wait_type eq "CLR_CRST">
		<cfreturn "Occurs when a task is currently performing CLR execution and is waiting to enter a critical section of the task that is currently being used by another task.">
	<cfelseif last_wait_type eq "CLR_JOIN">
		<cfreturn "Occurs when a task is currently performing CLR execution and waiting for another task to end. This wait state occurs when there is a join between tasks.">
	<cfelseif last_wait_type eq "CLR_MANUAL_EVENT">
		<cfreturn "Occurs when a task is currently performing CLR execution and is waiting for a specific manual event to be initiated.">
	<cfelseif last_wait_type eq "CLR_MONITOR">
		<cfreturn "Occurs when a task is currently performing CLR execution and is waiting to obtain a lock on the monitor.">
	<cfelseif last_wait_type eq "CLR_RWLOCK_READER">
		<cfreturn "Occurs when a task is currently performing CLR execution and is waiting for a reader lock.">
	<cfelseif last_wait_type eq "CLR_RWLOCK_WRITER">
		<cfreturn "Occurs when a task is currently performing CLR execution and is waiting for a writer lock.">
	<cfelseif last_wait_type eq "CLR_SEMAPHORE">
		<cfreturn "Occurs when a task is currently performing CLR execution and is waiting for a semaphore.">
	<cfelseif last_wait_type eq "CLR_TASK_START">
		<cfreturn "Occurs while waiting for a CLR task to complete startup.">
	<cfelseif last_wait_type eq "CMEMTHREAD">
		<cfreturn "Occurs when a task is waiting on a thread-safe memory object. The wait time might increase when there is contention caused by multiple tasks trying to allocate memory from the same memory object.">
	<cfelseif last_wait_type eq "CURSOR">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "CURSOR_ASYNC">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "CXPACKET">
		<cfreturn "Occurs when trying to synchronize the query processor exchange iterator. You may consider lowering the degree of parallelism if contention on this wait type becomes a problem.">
	<cfelseif last_wait_type eq "DBMIRROR_DBM_EVENT">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "DBMIRROR_DBM_MUTEX">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "DBMIRROR_EVENTS_QUEUE">
		<cfreturn "Occurs when database mirroring waits for events to process.">
	<cfelseif last_wait_type eq "DBMIRROR_SEND">
		<cfreturn "Occurs when a task is waiting for a communications backlog at the network layer to clear to be able to send messages. Indicates that the communications layer is starting to become overloaded and affect the database mirroring data throughput.">
	<cfelseif last_wait_type eq "DBMIRROR_WORKER_QUEUE">
		<cfreturn "Indicates that the database mirroring worker task is waiting for more work.">
	<cfelseif last_wait_type eq "DBMIRRORING_CMD">
		<cfreturn "Occurs when a task is waiting for log records to be flushed to disk. This wait state is expected to be held for long periods of time.">
	<cfelseif last_wait_type eq "DBTABLE">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "DEADLOCK_ENUM_MUTEX">
		<cfreturn "Occurs when the deadlock monitor and sys.dm_os_waiting_tasks try to make sure that SQL Server is not running multiple deadlock searches at the same time.">
	<cfelseif last_wait_type eq "DEADLOCK_TASK_SEARCH">
		<cfreturn "Large waiting time on this resource indicates that the server is executing queries on top of sys.dm_os_waiting_tasks, and these queries are blocking deadlock monitor from running deadlock search. This wait type is used by deadlock monitor only. Queries on top of sys.dm_os_waiting_tasks use DEADLOCK_ENUM_MUTEX.">
	<cfelseif last_wait_type eq "DEBUG">
		<cfreturn "Occurs during Transact-SQL and CLR debugging for internal synchronization.">
	<cfelseif last_wait_type eq "DISABLE_VERSIONING">
		<cfreturn "Occurs when SQL Server polls the version transaction manager to see whether the timestamp of the earliest active transaction is later than the timestamp of when the state started changing. If this is this case, all the snapshot transactions that were started before the ALTER DATABASE statement was run have finished. This wait state is used when SQL Server disables versioning by using the ALTER DATABASE statement.">
	<cfelseif last_wait_type eq "DISKIO_SUSPEND">
		<cfreturn "Occurs when a task is waiting to access a file when an external backup is active. This is reported for each waiting user process. A count larger than five per user process may indicate that the external backup is taking too much time to finish.">
	<cfelseif last_wait_type eq "DLL_LOADING_MUTEX">
		<cfreturn "Occurs once while waiting for the XML parser DLL to load.">
	<cfelseif last_wait_type eq "DROPTEMP">
		<cfreturn "Occurs between attempts to drop a temporary object if the previous attempt failed. The wait duration grows exponentially with each failed drop attempt.">
	<cfelseif last_wait_type eq "DTC">
		<cfreturn "Occurs when a task is waiting on an event that is used to manage state transition. This state controls when the recovery of Microsoft Distributed Transaction Coordinator (MS DTC) transactions occurs after SQL Server receives notification that the MS DTC service has become unavailable.">
	<cfelseif last_wait_type eq "">
		<cfreturn "This state also describes a task that is waiting when a commit of a MS DTC transaction is initiated by SQL Server and SQL Server is waiting for the MS DTC commit to finish.">
	<cfelseif last_wait_type eq "DTC_ABORT_REQUEST">
		<cfreturn "Occurs in a MS DTC worker session when the session is waiting to take ownership of a MS DTC transaction. After MS DTC owns the transaction, the session can roll back the transaction. Generally, the session will wait for another session that is using the transaction.">
	<cfelseif last_wait_type eq "DTC_RESOLVE">
		<cfreturn "Occurs when a recovery task is waiting for the master database in a cross-database transaction so that the task can query the outcome of the transaction.">
	<cfelseif last_wait_type eq "DTC_STATE">
		<cfreturn "Occurs when a task is waiting on an event that protects changes to the internal MS DTC global state object. This state should be held for very short periods of time.">
	<cfelseif last_wait_type eq "DTC_TMDOWN_REQUEST">
		<cfreturn "Occurs in a MS DTC worker session when SQL Server receives notification that the MS DTC service is not available. First, the worker will wait for the MS DTC recovery process to start. Then, the worker waits to obtain the outcome of the distributed transaction that the worker is working on. This may continue until the connection with the MS DTC service has been reestablished.">
	<cfelseif last_wait_type eq "DTC_WAITFOR_OUTCOME">
		<cfreturn "Occurs when recovery tasks wait for MS DTC to become active to enable the resolution of prepared transactions.">
	<cfelseif last_wait_type eq "DUMP_LOG_COORDINATOR">
		<cfreturn "Occurs when a main task is waiting for a subtask to generate data. Ordinarily, this state does not occur. A long wait indicates an unexpected blockage. The subtask should be investigated.">
	<cfelseif last_wait_type eq "EC">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "EE_PMOLOCK">
		<cfreturn "Occurs during synchronization of certain types of memory allocations during statement execution.">
	<cfelseif last_wait_type eq "EE_SPECPROC_MAP_INIT">
		<cfreturn "Occurs during synchronization of internal procedure hash table creation. This wait can only occur during the initial accessing of the hash table after the SQL Server 2005 instance starts.">
	<cfelseif last_wait_type eq "ENABLE_VERSIONING">
		<cfreturn "Occurs when SQL Server waits for all update transactions in this database to finish before declaring the database ready to transition to snapshot isolation allowed state. This state is used when SQL Server enables snapshot isolation by using the ALTER DATABASE statement.">
	<cfelseif last_wait_type eq "ERROR_REPORTING_MANAGER">
		<cfreturn "Occurs during synchronization of multiple concurrent error log initializations.">
	<cfelseif last_wait_type eq "EXCHANGE">
		<cfreturn "Occurs during synchronization in the query processor exchange iterator during parallel queries.">
	<cfelseif last_wait_type eq "EXECSYNC">
		<cfreturn "Occurs during parallel queries while synchronizing in query processor in areas not related to the exchange iterator. Examples of such areas are bitmaps, large binary objects (LOBs), and the spool iterator. LOBs may frequently use this wait state.">
	<cfelseif last_wait_type eq "FAILPOINT">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "FCB_REPLICA_READ">
		<cfreturn "Occurs when the reads of a snapshot (or a temporary snapshot created by DBCC) sparse file are synchronized.">
	<cfelseif last_wait_type eq "FCB_REPLICA_WRITE">
		<cfreturn "Occurs when the pushing or pulling of a page to a snapshot (or a temporary snapshot created by DBCC) sparse file is synchronized.">
	<cfelseif last_wait_type eq "FT_RESTART_CRAWL">
		<cfreturn "Occurs when a full-text crawl needs to restart from a last known good point to recover from a transient failure. The wait lets the worker tasks currently working on that population to complete or exit the current step.">
	<cfelseif last_wait_type eq "FT_RESUME_CRAWL">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "FULLTEXT GATHERER">
		<cfreturn "Occurs during synchronization of full-text operations.">
	<cfelseif last_wait_type eq "HTTP_ENDPOINT_COLLCREATE">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "HTTP_ENUMERATION">
		<cfreturn "Occurs at startup to enumerate the HTTP endpoints to start HTTP.">
	<cfelseif last_wait_type eq "HTTP_START">
		<cfreturn "Occurs when a connection is waiting for HTTP to complete initialization.">
	<cfelseif last_wait_type eq "IMP_IMPORT_MUTEX">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "IMPPROV_IOWAIT">
		<cfreturn "Occurs when SQL Server waits for a bulkload I/O to finish.">
	<cfelseif last_wait_type eq "INDEX_USAGE_STATS_MUTEX">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "IO_AUDIT_MUTEX">
		<cfreturn "Occurs during synchronization of trace event buffers.">
	<cfelseif last_wait_type eq "IO_COMPLETION">
		<cfreturn "Occurs while waiting for I/O operations to complete. This wait type generally represents non-data page I/Os. Data page I/O completion waits appear as PAGEIOLATCH_* waits.">
	<cfelseif last_wait_type eq "KSOURCE_WAKEUP">
		<cfreturn "Used by the service control task while waiting for requests from the Service Control Manager. Long waits are expected and do not indicate a problem.">
	<cfelseif last_wait_type eq "KTM_ENLISTMENT">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "KTM_RECOVERY_MANAGER">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "KTM_RECOVERY_RESOLUTION">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "LATCH_DT">
		<cfreturn "Occurs when waiting for a DT (destroy) latch. This does not include buffer latches or transaction mark latches. A listing of LATCH_* waits is available in sys.dm_os_latch_stats. Note that sys.dm_os_latch_stats groups LATCH_NL, LATCH_SH, LATCH_UP, LATCH_EX, and LATCH_DT waits together.">
	<cfelseif last_wait_type eq "LATCH_EX">
		<cfreturn "Occurs when waiting for an EX (exclusive) latch. This does not include buffer latches or transaction mark latches. A listing of LATCH_* waits is available in sys.dm_os_latch_stats. Note that sys.dm_os_latch_stats groups LATCH_NL, LATCH_SH, LATCH_UP, LATCH_EX, and LATCH_DT waits together.">
	<cfelseif last_wait_type eq "LATCH_KP">
		<cfreturn "Occurs when waiting for a KP (keep) latch. This does not include buffer latches or transaction mark latches. A listing of LATCH_* waits is available in sys.dm_os_latch_stats. Note that sys.dm_os_latch_stats groups LATCH_NL, LATCH_SH, LATCH_UP, LATCH_EX, and LATCH_DT waits together.">
	<cfelseif last_wait_type eq "LATCH_NL">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "LATCH_SH">
		<cfreturn "Occurs when waiting for an SH (share) latch. This does not include buffer latches or transaction mark latches. A listing of LATCH_* waits is available in sys.dm_os_latch_stats. Note that sys.dm_os_latch_stats groups LATCH_NL, LATCH_SH, LATCH_UP, LATCH_EX, and LATCH_DT waits together.">
	<cfelseif last_wait_type eq "LATCH_UP">
		<cfreturn "Occurs when waiting for an UP (update) latch. This does not include buffer latches or transaction mark latches. A listing of LATCH_* waits is available in sys.dm_os_latch_stats. Note that sys.dm_os_latch_stats groups LATCH_NL, LATCH_SH, LATCH_UP, LATCH_EX, and LATCH_DT waits together.">
	<cfelseif last_wait_type eq "LAZYWRITER_SLEEP">
		<cfreturn "Occurs when lazywriter tasks are suspended. This is a measure of the time spent by background tasks that are waiting. Do not consider this state when you are looking for user stalls.">
	<cfelseif last_wait_type eq "LCK_M_BU">
		<cfreturn "Occurs when a task is waiting to acquire a Bulk Update (BU) lock. For a lock compatibility matrix, see sys.dm_tran_locks.">
	<cfelseif last_wait_type eq "LCK_M_IS">
		<cfreturn "Occurs when a task is waiting to acquire an Intent Shared (IS) lock. For a lock compatibility matrix, see sys.dm_tran_locks.">
	<cfelseif last_wait_type eq "LCK_M_IU">
		<cfreturn "Occurs when a task is waiting to acquire an Intent Update (IU) lock. For a lock compatibility matrix, see sys.dm_tran_locks.">
	<cfelseif last_wait_type eq "LCK_M_IX">
		<cfreturn "Occurs when a task is waiting to acquire an Intent Exclusive (IX) lock. For a lock compatibility matrix, see sys.dm_tran_locks.">
	<cfelseif last_wait_type eq "LCK_M_RIn_NL">
		<cfreturn "Occurs when a task is waiting to acquire a NULL lock on the current key value, and an Insert Range lock between the current and previous key. A NULL lock on the key is an instant release lock. For a lock compatibility matrix, see sys.dm_tran_locks.">
	<cfelseif last_wait_type eq "LCK_M_RIn_S">
		<cfreturn "Occurs when a task is waiting to acquire a shared lock on the current key value, and an Insert Range lock between the current and previous key. For a lock compatibility matrix, see sys.dm_tran_locks.">
	<cfelseif last_wait_type eq "LCK_M_RIn_U">
		<cfreturn "Task is waiting to acquire an Update lock on the current key value, and an Insert Range lock between the current and previous key. For a lock compatibility matrix, see sys.dm_tran_locks.">
	<cfelseif last_wait_type eq "LCK_M_RIn_X">
		<cfreturn "Occurs when a task is waiting to acquire an Exclusive lock on the current key value, and an Insert Range lock between the current and previous key. For a lock compatibility matrix, see sys.dm_tran_locks.">
	<cfelseif last_wait_type eq "LCK_M_RS_S">
		<cfreturn "Occurs when a task is waiting to acquire a Shared lock on the current key value, and a Shared Range lock between the current and previous key. For a lock compatibility matrix, see sys.dm_tran_locks.">
	<cfelseif last_wait_type eq "LCK_M_RS_U">
		<cfreturn "Occurs when a task is waiting to acquire an Update lock on the current key value, and an Update Range lock between the current and previous key. For a lock compatibility matrix, see sys.dm_tran_locks.">
	<cfelseif last_wait_type eq "LCK_M_RX_S">
		<cfreturn "Occurs when a task is waiting to acquire a Shared lock on the current key value, and an Exclusive Range lock between the current and previous key. For a lock compatibility matrix, see sys.dm_tran_locks.">
	<cfelseif last_wait_type eq "LCK_M_RX_U">
		<cfreturn "Occurs when a task is waiting to acquire an Update lock on the current key value, and an Exclusive range lock between the current and previous key. For a lock compatibility matrix, see sys.dm_tran_locks.">
	<cfelseif last_wait_type eq "LCK_M_RX_X">
		<cfreturn "Occurs when a task is waiting to acquire an Exclusive lock on the current key value, and an Exclusive Range lock between the current and previous key. For a lock compatibility matrix, see sys.dm_tran_locks.">
	<cfelseif last_wait_type eq "LCK_M_S">
		<cfreturn "Occurs when a task is waiting to acquire a Shared lock. For a lock compatibility matrix, see sys.dm_tran_locks.">
	<cfelseif last_wait_type eq "LCK_M_SCH_M">
		<cfreturn "Occurs when a task is waiting to acquire a Schema Modify lock. For a lock compatibility matrix, see sys.dm_tran_locks.">
	<cfelseif last_wait_type eq "LCK_M_SCH_S">
		<cfreturn "Occurs when a task is waiting to acquire a Schema Share lock. For a lock compatibility matrix, see sys.dm_tran_locks.">
	<cfelseif last_wait_type eq "LCK_M_SIU">
		<cfreturn "Occurs when a task is waiting to acquire a Shared With Intent Update lock. For a lock compatibility matrix, see sys.dm_tran_locks.">
	<cfelseif last_wait_type eq "LCK_M_SIX">
		<cfreturn "Occurs when a task is waiting to acquire a Shared With Intent Exclusive lock. For a lock compatibility matrix, see sys.dm_tran_locks.">
	<cfelseif last_wait_type eq "LCK_M_U">
		<cfreturn "Occurs when a task is waiting to acquire an Update lock. For a lock compatibility matrix, see sys.dm_tran_locks.">
	<cfelseif last_wait_type eq "LCK_M_UIX">
		<cfreturn "Occurs when a task is waiting to acquire an Update With Intent Exclusive lock. For a lock compatibility matrix, see sys.dm_tran_locks.">
	<cfelseif last_wait_type eq "LCK_M_X">
		<cfreturn "Occurs when a task is waiting to acquire an Exclusive lock. For a lock compatibility matrix, see sys.dm_tran_locks.">
	<cfelseif last_wait_type eq "LOGBUFFER">
		<cfreturn "Occurs when a task is waiting for space in the log buffer to store a log record. Consistently high values may indicate that the log devices cannot keep up with the amount of log being generated by the server.">
	<cfelseif last_wait_type eq "LOGMGR">
		<cfreturn "Occurs when a task is waiting for any outstanding log I/Os to finish before shutting down the log while closing the database.">
	<cfelseif last_wait_type eq "LOGMGR_FLUSH">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "LOGMGR_QUEUE">
		<cfreturn "Occurs while the log writer task waits for work requests.">
	<cfelseif last_wait_type eq "LOGMGR_RESERVE_APPEND">
		<cfreturn "Occurs when a task is waiting to see whether log truncation frees up log space to enable the task to write a new log record. Consider increasing the size of the log file(s) for the affected database to reduce this wait.">
	<cfelseif last_wait_type eq "LOWFAIL_MEMMGR_QUEUE">
		<cfreturn "Occurs while waiting for memory to be available for use.">
	<cfelseif last_wait_type eq "MIRROR_SEND_MESSAGE">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "MISCELLANEOUS">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "MSQL_DQ">
		<cfreturn "Occurs when a task is waiting for a distributed query operation to finish. This is used to detect potential Multiple Active Result Set (MARS) application deadlocks. The wait ends when the distributed query call finishes.">
	<cfelseif last_wait_type eq "MSQL_SYNC_PIPE">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "MSQL_XACT_MGR_MUTEX">
		<cfreturn "Occurs when a task is waiting to obtain ownership of the session transaction manager to perform a session level transaction operation.">
	<cfelseif last_wait_type eq "MSQL_XACT_MUTEX">
		<cfreturn "Occurs during synchronization of transaction usage. A request must acquire the mutex before it can use the transaction.">
	<cfelseif last_wait_type eq "MSQL_XP">
		<cfreturn "Occurs when a task is waiting for an extended stored procedure to end. SQL Server uses this wait state to detect potential MARS application deadlocks. The wait stops when the extended stored procedure call ends.">
	<cfelseif last_wait_type eq "MSSEARCH">
		<cfreturn "Occurs during Full-Text Search calls. This wait ends when the full-text operation completes. It does not indicate contention, but rather the duration of full-text operations.">
	<cfelseif last_wait_type eq "NET_WAITFOR_PACKET">
		<cfreturn "Occurs when a connection is waiting for a network packet during a network read.">
	<cfelseif last_wait_type eq "OLEDB">
		<cfreturn "Occurs when SQL Server calls the Microsoft SQL Native Client OLE DB Provider. This wait type is not used for synchronization. Instead, it indicates the duration of calls to the OLEDB provider.">
	<cfelseif last_wait_type eq "ONDEMAND_TASK_QUEUE">
		<cfreturn "Occurs while a background task waits for high priority system task requests. Long wait times indicate that there have been no high priority requests to process, and should not cause concern.">
	<cfelseif last_wait_type eq "PAGEIOLATCH_DT">
		<cfreturn "Occurs when a task is waiting on a latch for a buffer that is in an I/O request. The latch request is in Destroy mode. Long waits may indicate problems with the disk subsystem.">
	<cfelseif last_wait_type eq "PAGEIOLATCH_EX">
		<cfreturn "Occurs when a task is waiting on a latch for a buffer that is in an I/O request. The latch request is in Exclusive mode. Long waits may indicate problems with the disk subsystem.">
	<cfelseif last_wait_type eq "PAGEIOLATCH_KP">
		<cfreturn "Occurs when a task is waiting on a latch for a buffer that is in an I/O request. The latch request is in Keep mode. Long waits may indicate problems with the disk subsystem.">
	<cfelseif last_wait_type eq "PAGEIOLATCH_NL">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "PAGEIOLATCH_SH">
		<cfreturn "Occurs when a task is waiting on a latch for a buffer that is in an I/O request. The latch request is in Shared mode. Long waits may indicate problems with the disk subsystem.">
	<cfelseif last_wait_type eq "PAGEIOLATCH_UP">
		<cfreturn "Occurs when a task is waiting on a latch for a buffer that is in an I/O request. The latch request is in Update mode. Long waits may indicate problems with the disk subsystem.">
	<cfelseif last_wait_type eq "PAGELATCH_DT">
		<cfreturn "Occurs when a task is waiting on a latch for a buffer that is not in an I/O request. The latch request is in Destroy mode.">
	<cfelseif last_wait_type eq "PAGELATCH_EX">
		<cfreturn "Occurs when a task is waiting on a latch for a buffer that is not in an I/O request. The latch request is in Exclusive mode.">
	<cfelseif last_wait_type eq "PAGELATCH_KP">
		<cfreturn "Occurs when a task is waiting on a latch for a buffer that is not in an I/O request. The latch request is in Keep mode.">
	<cfelseif last_wait_type eq "PAGELATCH_NL">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "PAGELATCH_SH">
		<cfreturn "Occurs when a task is waiting on a latch for a buffer that is not in an I/O request. The latch request is in Shared mode.">
	<cfelseif last_wait_type eq "PAGELATCH_UP">
		<cfreturn "Occurs when a task is waiting on a latch for a buffer that is not in an I/O request. The latch request is in Update mode.">
	<cfelseif last_wait_type eq "PARALLEL_BACKUP_QUEUE">
		<cfreturn "Occurs when serializing output produced by RESTORE HEADERONLY, RESTORE FILELISTONLY, or RESTORE LABELONLY.">
	<cfelseif last_wait_type eq "PRINT_ROLLBACK_PROGRESS">
		<cfreturn "Used to wait while user processes are ended in a database that has been transitioned by using the ALTER DATABASE termination clause. For more information, see ALTER DATABASE (Transact-SQL).">
	<cfelseif last_wait_type eq "QNMANAGER_ACQUIRE">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "QPJOB_KILL">
		<cfreturn "Indicates that an asynchronous automatic statistics update was canceled by a call to KILL as the update was starting to run. The terminating thread is suspended, waiting for it to start listening for KILL commands. A good value is less than one second.">
	<cfelseif last_wait_type eq "QPJOB_WAITFOR_ABORT">
		<cfreturn "Indicates that an asynchronous automatic statistics update was canceled by a call to KILL when it was running. The update has now completed but is suspended until the terminating thread message coordination is complete. This is an ordinary but rare state, and should be very short. A good value is less than one second.">
	<cfelseif last_wait_type eq "QRY_MEM_GRANT_INFO_MUTEX">
		<cfreturn "Occurs when Query Execution memory management tries to control access to static grant information list. This state lists information about the current granted and waiting memory requests. This state is a simple access control state. There should never be a long wait on this state. If this mutex is not released, all new memory-using queries will stop responding.">
	<cfelseif last_wait_type eq "QUERY_EXECUTION_INDEX_SORT_EVENT_OPEN">
		<cfreturn "Occurs in certain cases when offline create index build is run in parallel, and the different worker threads that are sorting synchronize access to the sort files.">
	<cfelseif last_wait_type eq "QUERY_NOTIFICATION_MGR_MUTEX">
		<cfreturn "Occurs during synchronization of the garbage collection queue in the Query Notification Manager.">
	<cfelseif last_wait_type eq "QUERY_NOTIFICATION_SUBSCRIPTION_MUTEX">
		<cfreturn "Occurs during state synchronization for transactions in Query Notifications.">
	<cfelseif last_wait_type eq "QUERY_NOTIFICATION_TABLE_MGR_MUTEX">
		<cfreturn "Occurs during internal synchronization within the Query Notification Manager.">
	<cfelseif last_wait_type eq "QUERY_NOTIFICATION_UNITTEST_MUTEX">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "QUERY_OPTIMIZER_PRINT_MUTEX">
		<cfreturn "Occurs during synchronization of query optimizer diagnostic output production. This wait type only occurs if diagnostic settings have been enabled under direction of Microsoft Product Support.">
	<cfelseif last_wait_type eq "QUERY_TRACEOUT">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "RECOVER_CHANGEDB">
		<cfreturn "Occurs during synchronization of database status in warm standby database.">
	<cfelseif last_wait_type eq "REPL_CACHE_ACCESS">
		<cfreturn "Occurs during synchronization on a replication article cache. During these waits, the replication log reader stalls, and data definition language (DDL) statements on a published table are blocked.">
	<cfelseif last_wait_type eq "REPL_SCHEMA_ACCESS">
		<cfreturn "Occurs during synchronization of replication schema version information. This state exists when DDL statements are executed on the replicated object, and when the log reader builds or consumes versioned schema based on DDL occurrence.">
	<cfelseif last_wait_type eq "REPLICA_WRITES">
		<cfreturn "Occurs while a task waits for completion of page writes to database snapshots or DBCC replicas.">
	<cfelseif last_wait_type eq "REQUEST_DISPENSER_PAUSE">
		<cfreturn "Occurs when a task is waiting for all outstanding I/O to complete, so that I/O to a file can be frozen for snapshot backup.">
	<cfelseif last_wait_type eq "REQUEST_FOR_DEADLOCK_SEARCH">
		<cfreturn "Occurs while the deadlock monitor waits to start the next deadlock search. This wait is expected between deadlock detections, and lengthy total waiting time on this resource does not indicate a problem.">
	<cfelseif last_wait_type eq "RESOURCE_QUEUE">
		<cfreturn "Occurs during synchronization of various internal resource queues.">
	<cfelseif last_wait_type eq "RESOURCE_SEMAPHORE">
		<cfreturn "Occurs when a query memory request cannot be granted immediately due to other concurrent queries. High waits and wait times may indicate excessive number of concurrent queries, or excessive memory request amounts.">
	<cfelseif last_wait_type eq "RESOURCE_SEMAPHORE_MUTEX">
		<cfreturn "Occurs while a query waits for its request for a thread reservation to be fulfilled. It also occurs when synchronizing query compile and memory grant requests.">
	<cfelseif last_wait_type eq "RESOURCE_SEMAPHORE_QUERY_COMPILE">
		<cfreturn "Occurs when the number of concurrent query compilations reaches a throttling limit. High waits and wait times may indicate excessive compilations, recompiles, or uncachable plans.">
	<cfelseif last_wait_type eq "RESOURCE_SEMAPHORE_SMALL_QUERY">
		<cfreturn "Occurs when memory request by a small query cannot be granted immediately due to other concurrent queries. Wait time should not exceed more than a few seconds, because the server transfers the request to the main query memory pool if it fails to grant the requested memory within a few seconds. High waits may indicate an excessive number of concurrent small queries while the main memory pool is blocked by waiting queries.">
	<cfelseif last_wait_type eq "SEC_DROP_TEMP_KEY">
		<cfreturn "Occurs after a failed attempt to drop a temporary security key before a retry attempt.">
	<cfelseif last_wait_type eq "SERVER_IDLE_CHECK">
		<cfreturn "Occurs during synchronization of SQL Server instance idle status when a resource monitor is attempting to declare a SQL Server instance as idle or trying to wake up.">
	<cfelseif last_wait_type eq "SHUTDOWN">
		<cfreturn "Occurs while a shutdown statement waits for active connections to exit.">
	<cfelseif last_wait_type eq "SLEEP_BPOOL_FLUSH">
		<cfreturn "Occurs when a checkpoint is throttling the issuance of new I/Os in order to avoid flooding the disk subsystem.">
	<cfelseif last_wait_type eq "SLEEP_DBSTARTUP">
		<cfreturn "Occurs during database startup while waiting for all databases to recover.">
	<cfelseif last_wait_type eq "SLEEP_DCOMSTARTUP">
		<cfreturn "Occurs once at most during SQL Server instance startup while waiting for DCOM initialization to complete.">
	<cfelseif last_wait_type eq "SLEEP_MSDBSTARTUP">
		<cfreturn "Occurs when SQL Trace waits for the msdb database to complete startup.">
	<cfelseif last_wait_type eq "SLEEP_SYSTEMTASK">
		<cfreturn "Occurs during the start of a background task while waiting for tempdb to complete startup.">
	<cfelseif last_wait_type eq "SLEEP_TASK">
		<cfreturn "Occurs when a task sleeps while waiting for a generic event to occur.">
	<cfelseif last_wait_type eq "SLEEP_TEMPDBSTARTUP">
		<cfreturn "Occurs while a task waits for tempdb to complete startup.">
	<cfelseif last_wait_type eq "SNI_CRITICAL_SECTION">
		<cfreturn "Occurs during internal synchronization within SQL Server networking components.">
	<cfelseif last_wait_type eq "SNI_HTTP_ACCEPT">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "SNI_HTTP_WAITFOR_0_DISCON">
		<cfreturn "Occurs during SQL Server shutdown, while waiting for outstanding HTTP connections to exit.">
	<cfelseif last_wait_type eq "SOAP_READ">
		<cfreturn "Occurs while waiting for an HTTP network read to complete.">
	<cfelseif last_wait_type eq "SOAP_WRITE">
		<cfreturn "Occurs while waiting for an HTTP network write to complete.">
	<cfelseif last_wait_type eq "SOS_CALLBACK_REMOVAL">
		<cfreturn "Occurs while performing synchronization on a callback list in order to remove a callback. It is not expected for this counter to change after server initialization is completed.">
	<cfelseif last_wait_type eq "SOS_LOCALALLOCATORLIST">
		<cfreturn "Occurs during internal synchronization in the SQL Server memory manager.">
	<cfelseif last_wait_type eq "SOS_OBJECT_STORE_DESTROY_MUTEX">
		<cfreturn "Occurs during internal synchronization in memory pools when destroying objects from the pool.">
	<cfelseif last_wait_type eq "SOS_PROCESS_AFFINITY_MUTEX">
		<cfreturn "Occurs during synchronizing of access to process affinity settings.">
	<cfelseif last_wait_type eq "SOS_RESERVEDMEMBLOCKLIST">
		<cfreturn "Occurs during internal synchronization in the SQL Server memory manager.">
	<cfelseif last_wait_type eq "SOS_SCHEDULER_YIELD">
		<cfreturn "Occurs when a task voluntarily yields the scheduler for other tasks to execute. During this wait the task is waiting for its quantum to be renewed.">
	<cfelseif last_wait_type eq "SOS_STACKSTORE_INIT_MUTEX">
		<cfreturn "Occurs during synchronization of internal store initialization.">
	<cfelseif last_wait_type eq "SOS_SYNC_TASK_ENQUEUE_EVENT">
		<cfreturn "Occurs when a task is started in a synchronous manner. Most tasks in SQL Server are started in an asynchronous manner, in which control returns to the starter immediately after the task request has been placed on the work queue.">
	<cfelseif last_wait_type eq "SOS_VIRTUALMEMORY_LOW">
		<cfreturn "Occurs when a memory allocation waits for a resource manager to free up virtual memory.">
	<cfelseif last_wait_type eq "SOSHOST_EVENT">
		<cfreturn "Occurs when a hosted component, such as CLR, waits on a SQL Server 2005 event synchronization object.">
	<cfelseif last_wait_type eq "SOSHOST_INTERNAL">
		<cfreturn "Occurs during synchronization of memory manager callbacks used by hosted components, such as CLR.">
	<cfelseif last_wait_type eq "SOSHOST_MUTEX">
		<cfreturn "Occurs when a hosted component, such as CLR, waits on a SQL Server 2005 mutex synchronization object.">
	<cfelseif last_wait_type eq "SOSHOST_RWLOCK">
		<cfreturn "Occurs when a hosted component, such as CLR, waits on a SQL Server 2005 reader-writer synchronization object.">
	<cfelseif last_wait_type eq "SOSHOST_SEMAPHORE">
		<cfreturn "Occurs when a hosted component, such as CLR, waits on a SQL Server 2005 semaphore synchronization object.">
	<cfelseif last_wait_type eq "SOSHOST_SLEEP">
		<cfreturn "Occurs when a hosted task sleeps while waiting for a generic event to occur. Hosted tasks are used by hosted components such as CLR.">
	<cfelseif last_wait_type eq "SOSHOST_TRACELOCK">
		<cfreturn "Occurs during synchronization of access to trace streams.">
	<cfelseif last_wait_type eq "SOSHOST_WAITFORDONE">
		<cfreturn "Occurs when a hosted component, such as CLR, waits for a task to complete.">
	<cfelseif last_wait_type eq "SQLCLR_APPDOMAIN">
		<cfreturn "Occurs while CLR waits for an application domain to complete startup.">
	<cfelseif last_wait_type eq "SQLCLR_ASSEMBLY">
		<cfreturn "Occurs while waiting for access to the loaded assembly list in the appdomain.">
	<cfelseif last_wait_type eq "SQLCLR_DEADLOCK_DETECTION">
		<cfreturn "Occurs while CLR waits for deadlock detection to complete.">
	<cfelseif last_wait_type eq "SQLCLR_QUANTUM_PUNISHMENT">
		<cfreturn "Occurs when a CLR task is throttled because it has exceeded its execution quantum. This throttling is done in order to reduce the effect of this resource-intensive task on other tasks.">
	<cfelseif last_wait_type eq "SQLSORT_NORMMUTEX">
		<cfreturn "Occurs during internal synchronization, while initializing internal sorting structures.">
	<cfelseif last_wait_type eq "SQLSORT_SORTMUTEX">
		<cfreturn "Occurs during internal synchronization, while initializing internal sorting structures.">
	<cfelseif last_wait_type eq "SQLTRACE_BUFFER_FLUSH">
		<cfreturn "Occurs when a task is waiting for a background task to flush trace buffers to disk every four seconds.">
	<cfelseif last_wait_type eq "SQLTRACE_LOCK">
		<cfreturn "Occurs during synchronization on trace buffers during a file trace.">
	<cfelseif last_wait_type eq "SQLTRACE_SHUTDOWN">
		<cfreturn "Occurs while trace shutdown waits for outstanding trace events to complete.">
	<cfelseif last_wait_type eq "SQLTRACE_WAIT_ENTRIES">
		<cfreturn "Occurs while a SQL Trace event queue waits for packets to arrive on the queue.">
	<cfelseif last_wait_type eq "SRVPROC_SHUTDOWN">
		<cfreturn "Occurs while the shutdown process waits for internal resources to be released to shutdown cleanly.">
	<cfelseif last_wait_type eq "TEMPOBJ">
		<cfreturn "Occurs when temporary object drops are synchronized. This wait is rare, and only occurs if a task has requested exclusive access for temp table drops.">
	<cfelseif last_wait_type eq "THREADPOOL">
		<cfreturn "Occurs when a task is waiting for a worker to run on. This can indicate that the maximum worker setting is too low, or that batch executions are taking unusually long, thus reducing the number of workers available to satisfy other batches.">
	<cfelseif last_wait_type eq "TRACEWRITE">
		<cfreturn "Occurs when the SQL Trace rowset trace provider waits for either a free buffer or a buffer with events to process.">
	<cfelseif last_wait_type eq "TRAN_MARKLATCH_DT">
		<cfreturn "Occurs when waiting for a destroy mode latch on a transaction mark latch. Transaction mark latches are used for synchronization of commits with marked transactions.">
	<cfelseif last_wait_type eq "TRAN_MARKLATCH_EX">
		<cfreturn "Occurs when waiting for an exclusive mode latch on a marked transaction. Transaction mark latches are used for synchronization of commits with marked transactions.">
	<cfelseif last_wait_type eq "TRAN_MARKLATCH_KP">
		<cfreturn "Occurs when waiting for a keep mode latch on a marked transaction. Transaction mark latches are used for synchronization of commits with marked transactions.">
	<cfelseif last_wait_type eq "TRAN_MARKLATCH_NL">
		<cfreturn "Internal only.">
	<cfelseif last_wait_type eq "TRAN_MARKLATCH_SH">
		<cfreturn "Occurs when waiting for a shared mode latch on a marked transaction. Transaction mark latches are used for synchronization of commits with marked transactions.">
	<cfelseif last_wait_type eq "TRAN_MARKLATCH_UP">
		<cfreturn "Occurs when waiting for an update mode latch on a marked transaction. Transaction mark latches are used for synchronization of commits with marked transactions.">
	<cfelseif last_wait_type eq "TRANSACTION_MUTEX">
		<cfreturn "Occurs during synchronization of access to a transaction by multiple batches.">
	<cfelseif last_wait_type eq "UTIL_PAGE_ALLOC">
		<cfreturn "Occurs when transaction log scans wait for memory to be available during memory pressure.">
	<cfelseif last_wait_type eq "VIEW_DEFINITION_MUTEX">
		<cfreturn "Occurs during synchronization on access to cached view definitions.">
	<cfelseif last_wait_type eq "WAIT_FOR_RESULTS">
		<cfreturn "Occurs when waiting for a query notification to be triggered.">
	<cfelseif last_wait_type eq "WAITFOR">
		<cfreturn "Occurs as a result of a WAITFOR Transact-SQL statement. The duration of the wait is determined by the parameters to the statement. This is a user-initiated wait.">
	<cfelseif last_wait_type eq "WAITSTAT_MUTEX">
		<cfreturn "Occurs during synchronization of access to the collection of statistics used to populate sys.dm_os_wait_stats.">
	<cfelseif last_wait_type eq "WORKTBL_DROP">
		<cfreturn "Occurs while pausing before retrying, after a failed worktable drop.">
	<cfelseif last_wait_type eq "WRITELOG">
		<cfreturn "Occurs while waiting for a log flush to complete. Common operations that cause log flushes are checkpoints and transaction commits.">
	<cfelseif last_wait_type eq "XACT_OWN_TRANSACTION">
		<cfreturn "Occurs while waiting to acquire ownership of a transaction.">
	<cfelseif last_wait_type eq "XACT_RECLAIM_SESSION">
		<cfreturn "Occurs while waiting for the current owner of a session to release ownership of the session.">
	<cfelseif last_wait_type eq "XACTLOCKINFO">
		<cfreturn "Occurs during synchronization of access to the list of locks for a transaction. In addition to the transaction itself, the list of locks is accessed by operations such as deadlock detection and lock migration during page splits.">
	<cfelseif last_wait_type eq "XACTWORKSPACE_MUTEX">
		<cfreturn "Occurs during synchronization of defections from a transaction, as well as the number of database locks between enlist members of a transaction.">
	<cfelse>
		<cfreturn "">
	</cfif>
</cffunction>

