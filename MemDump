Novo  de MemDump - salvar como .PS1
==================================



detections


http://dontpad.com/paralelepipedo8819




(event_simpleName=processrollup2 OR event_simpleName=syntheticprocessrollup2 OR event_simpleName=associatetreeidwithroot OR event_simpleName=cloudassociatetreeidwithroot OR event_simpleName=associateindicator OR ExternalApiType=Event_DetectionSummaryEvent)
| eval MasterPID=coalesce(ProcessId, TargetProcessId_decimal)
| stats values(CommandLine) AS Triggering_CL, values(PatternId_decimal) AS PatternID, values(TemplateInstanceId_decimal) AS InstanceID, values(DetectScenario) AS Scenario, values(DetectName) AS Name, values(DetectDeion) AS Deion, values(Nonce) AS Ignore by MasterPID
| where Triggering_CL!="" AND PatternID!="" AND isnull(Ignore)




https://falcon.us-2.crowdstrike.com/crowdscore/incidents/details/inc:68efad3dd29d49b0808c463a2119359c:26cf72a025504afa8ab0c38421bd88ae/graph



earliest=-7d event_simpleName=UserLogonFailed2
| iplocation RemoteIP
| stats dc(aid) as uniqueSystems count(aid) as failedLogonAttempts values(Country) as Countries values(ComputerName) as Endpoints by company
| sort – failedLogonAttempts



https://falcon.us-2.crowdstrike.com/support/news/release-notes-falcon-sensor-for-linux-6-12-10912
