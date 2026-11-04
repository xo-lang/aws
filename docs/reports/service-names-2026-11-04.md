# Service names and protocols over every model (2026-11-04)

Models: api-models-aws at commit 1b9ff13fe6c28ea9774a527e53cda6a3b91369dc
(codegen/models.lock), 435 services, one model version each.

Rule (decision 0001): directory = sdkId lower cased with spaces removed;
local name = directory with `-` as `_` and any other character outside
`[a-z0-9_]` dropped. Checked against Xo's 28 keywords, the predeclared
identifiers (`true false self target fault dbg Ok Err Some None`), the
core's directory names (`sigv4 sigv4a credentials config retry endpoints
protocol eventstream transport checksum internal codegen examples
integration docs scripts`), validity as an identifier, and duplicates.

## Result

- No service name is a keyword, a predeclared identifier, a core
  directory, an invalid identifier, or a duplicate. No sdkId holds a
  character other than letters, digits, and spaces, so directory and
  local name are always equal.
- `signer` (AWS Signer) is a service: Go's core `signer/v4` layout would
  have collided; decision 0001's `sigv4` avoids it.
- `config-service` is `configservice`, so the core's `config/` is free.

## Protocols

| protocol traits on the service | services |
|---|---|
| restJson1 | 259 |
| awsJson1_1 | 92 |
| awsJson1_0 | 38 |
| awsQuery | 15 |
| awsJson1_0,rpcv2Cbor | 11 |
| awsJson1_1,rpcv2Cbor | 10 |
| restXml | 4 |
| rpcv2Cbor | 3 |
| awsJson1_0,awsQuery,awsQueryCompatible,rpcv2Cbor | 1 |
| ec2Query | 1 |
| awsJson1_0,awsQueryCompatible | 1 |

Consequences for the design:

- Smithy RPC v2 CBOR is not optional: 3 services speak only CBOR
  (`cloudwatchomni`, `eventbridgev2`, `partnercentral-revenue-measurement`)
  and 22 more list it next to a JSON or query protocol, CloudWatch among
  them. Decision 0006 item 6 (CBOR codec) moves from later to required for
  full coverage; services offering JSON or query as well can use that
  first.
- `awsQueryCompatible` is on SQS (a first wave service) and CloudWatch: the
  JSON protocol with query compatible error codes (the
  `x-amzn-query-error` header). The core's error parsing needs it for SQS.
- ec2Query is EC2 alone; restXml is 4 services (S3, S3 Control,
  CloudFront, Route 53).

## Largest services (operations, shapes)

| model | operations | shapes |
|---|---|---|
| ec2 | 811 | 5109 |
| sagemaker | 409 | 3506 |
| quicksight | 299 | 3184 |
| connect | 404 | 2815 |
| glue | 306 | 2209 |
| iot | 272 | 1800 |
| securityhub | 123 | 1651 |
| bedrock-agentcore-control | 172 | 1576 |
| ssm | 152 | 1493 |
| datazone | 195 | 1399 |

## Every service

| model directory | sdkId | package | protocols | operations |
|---|---|---|---|---|
| accessanalyzer | AccessAnalyzer | accessanalyzer | restJson1 | 39 |
| account-access | Account Access | accountaccess | restJson1 | 11 |
| account | Account | account | restJson1 | 18 |
| acm-pca | ACM PCA | acmpca | awsJson1_1 | 23 |
| acm | ACM | acm | awsJson1_1 | 40 |
| agent-registry-control | Agent Registry Control | agentregistrycontrol | restJson1 | 15 |
| agent-registry | Agent Registry | agentregistry | restJson1 | 3 |
| aiops | AIOps | aiops | restJson1 | 11 |
| amp | amp | amp | restJson1 | 44 |
| amplify | Amplify | amplify | restJson1 | 37 |
| amplifybackend | AmplifyBackend | amplifybackend | restJson1 | 31 |
| amplifyuibuilder | AmplifyUIBuilder | amplifyuibuilder | restJson1 | 28 |
| api-gateway | API Gateway | apigateway | restJson1 | 124 |
| apigatewaymanagementapi | ApiGatewayManagementApi | apigatewaymanagementapi | restJson1 | 3 |
| apigatewayv2 | ApiGatewayV2 | apigatewayv2 | restJson1 | 103 |
| app-mesh | App Mesh | appmesh | restJson1 | 38 |
| appconfig | AppConfig | appconfig | restJson1 | 56 |
| appconfigdata | AppConfigData | appconfigdata | restJson1 | 2 |
| appfabric | AppFabric | appfabric | restJson1 | 26 |
| appflow | Appflow | appflow | restJson1 | 25 |
| appintegrations | AppIntegrations | appintegrations | restJson1 | 23 |
| application-auto-scaling | Application Auto Scaling | applicationautoscaling | awsJson1_1 | 14 |
| application-discovery-service | Application Discovery Service | applicationdiscoveryservice | awsJson1_1 | 28 |
| application-insights | Application Insights | applicationinsights | awsJson1_1,rpcv2Cbor | 33 |
| application-signals | Application Signals | applicationsignals | restJson1 | 30 |
| applicationcostprofiler | ApplicationCostProfiler | applicationcostprofiler | restJson1 | 6 |
| apprunner | AppRunner | apprunner | awsJson1_0 | 37 |
| appstream | AppStream | appstream | awsJson1_1,rpcv2Cbor | 89 |
| appsync | AppSync | appsync | restJson1 | 74 |
| arc-region-switch | ARC Region switch | arcregionswitch | awsJson1_0,rpcv2Cbor | 22 |
| arc-zonal-shift | ARC Zonal Shift | arczonalshift | restJson1 | 15 |
| artifact | Artifact | artifact | restJson1 | 17 |
| athena | Athena | athena | awsJson1_1 | 70 |
| auditmanager | AuditManager | auditmanager | restJson1 | 62 |
| auto-scaling-plans | Auto Scaling Plans | autoscalingplans | awsJson1_1 | 6 |
| auto-scaling | Auto Scaling | autoscaling | awsQuery | 68 |
| b2bi | b2bi | b2bi | awsJson1_0 | 30 |
| backup-gateway | Backup Gateway | backupgateway | awsJson1_0,rpcv2Cbor | 25 |
| backup | Backup | backup | restJson1 | 115 |
| backupsearch | BackupSearch | backupsearch | restJson1 | 12 |
| batch | Batch | batch | restJson1 | 48 |
| bcm-dashboards | BCM Dashboards | bcmdashboards | awsJson1_0 | 15 |
| bcm-data-exports | BCM Data Exports | bcmdataexports | awsJson1_1 | 12 |
| bcm-pricing-calculator | BCM Pricing Calculator | bcmpricingcalculator | awsJson1_0 | 36 |
| bcm-recommended-actions | BCM Recommended Actions | bcmrecommendedactions | awsJson1_0 | 1 |
| bedrock-agent-runtime | Bedrock Agent Runtime | bedrockagentruntime | restJson1 | 35 |
| bedrock-agent | Bedrock Agent | bedrockagent | restJson1 | 86 |
| bedrock-agentcore-control | Bedrock AgentCore Control | bedrockagentcorecontrol | restJson1 | 172 |
| bedrock-agentcore | Bedrock AgentCore | bedrockagentcore | restJson1 | 67 |
| bedrock-data-automation-runtime | Bedrock Data Automation Runtime | bedrockdataautomationruntime | awsJson1_1 | 6 |
| bedrock-data-automation | Bedrock Data Automation | bedrockdataautomation | restJson1 | 27 |
| bedrock-runtime | Bedrock Runtime | bedrockruntime | restJson1 | 11 |
| bedrock | Bedrock | bedrock | restJson1 | 108 |
| billing | Billing | billing | awsJson1_0 | 32 |
| billingconductor | billingconductor | billingconductor | restJson1 | 34 |
| braket | Braket | braket | restJson1 | 17 |
| budgets | Budgets | budgets | awsJson1_1 | 26 |
| chatbot | chatbot | chatbot | restJson1 | 34 |
| chime-sdk-identity | Chime SDK Identity | chimesdkidentity | restJson1 | 30 |
| chime-sdk-media-pipelines | Chime SDK Media Pipelines | chimesdkmediapipelines | restJson1 | 31 |
| chime-sdk-meetings | Chime SDK Meetings | chimesdkmeetings | restJson1 | 16 |
| chime-sdk-messaging | Chime SDK Messaging | chimesdkmessaging | restJson1 | 51 |
| chime-sdk-voice | Chime SDK Voice | chimesdkvoice | restJson1 | 96 |
| chime | Chime | chime | restJson1 | 62 |
| cleanrooms | CleanRooms | cleanrooms | restJson1 | 103 |
| cleanroomsml | CleanRoomsML | cleanroomsml | restJson1 | 59 |
| cloud9 | Cloud9 | cloud9 | awsJson1_1 | 13 |
| cloudcontrol | CloudControl | cloudcontrol | awsJson1_0 | 8 |
| clouddirectory | CloudDirectory | clouddirectory | restJson1 | 66 |
| cloudformation | CloudFormation | cloudformation | awsQuery | 90 |
| cloudfront-keyvaluestore | CloudFront KeyValueStore | cloudfrontkeyvaluestore | restJson1 | 6 |
| cloudfront | CloudFront | cloudfront | restXml | 167 |
| cloudhsm-v2 | CloudHSM V2 | cloudhsmv2 | awsJson1_1 | 18 |
| cloudhsm | CloudHSM | cloudhsm | awsJson1_1 | 20 |
| cloudsearch-domain | CloudSearch Domain | cloudsearchdomain | restJson1 | 3 |
| cloudsearch | CloudSearch | cloudsearch | awsQuery | 26 |
| cloudtrail-data | CloudTrail Data | cloudtraildata | restJson1 | 1 |
| cloudtrail | CloudTrail | cloudtrail | awsJson1_1 | 60 |
| cloudwatch-events | CloudWatch Events | cloudwatchevents | awsJson1_1 | 51 |
| cloudwatch-logs | CloudWatch Logs | cloudwatchlogs | awsJson1_1 | 118 |
| cloudwatch | CloudWatch | cloudwatch | awsJson1_0,awsQuery,awsQueryCompatible,rpcv2Cbor | 55 |
| cloudwatchomni | CloudWatchOmni | cloudwatchomni | rpcv2Cbor | 61 |
| codeartifact | codeartifact | codeartifact | restJson1 | 48 |
| codebuild | CodeBuild | codebuild | awsJson1_1 | 59 |
| codecatalyst | CodeCatalyst | codecatalyst | restJson1 | 38 |
| codecommit | CodeCommit | codecommit | awsJson1_1 | 80 |
| codeconnections | CodeConnections | codeconnections | awsJson1_0,rpcv2Cbor | 27 |
| codedeploy | CodeDeploy | codedeploy | awsJson1_1 | 47 |
| codeguru-reviewer | CodeGuru Reviewer | codegurureviewer | restJson1 | 14 |
| codeguru-security | CodeGuru Security | codegurusecurity | restJson1 | 13 |
| codeguruprofiler | CodeGuruProfiler | codeguruprofiler | restJson1 | 23 |
| codepipeline | CodePipeline | codepipeline | awsJson1_1 | 44 |
| codestar-connections | CodeStar connections | codestarconnections | awsJson1_0 | 27 |
| codestar-notifications | codestar notifications | codestarnotifications | restJson1 | 13 |
| cognito-identity-provider | Cognito Identity Provider | cognitoidentityprovider | awsJson1_1 | 132 |
| cognito-identity | Cognito Identity | cognitoidentity | awsJson1_1 | 23 |
| cognito-sync | Cognito Sync | cognitosync | restJson1 | 17 |
| comprehend | Comprehend | comprehend | awsJson1_1 | 85 |
| comprehendmedical | ComprehendMedical | comprehendmedical | awsJson1_1,rpcv2Cbor | 26 |
| compute-optimizer-automation | Compute Optimizer Automation | computeoptimizerautomation | awsJson1_0,rpcv2Cbor | 23 |
| compute-optimizer | Compute Optimizer | computeoptimizer | awsJson1_0,rpcv2Cbor | 28 |
| config-service | Config Service | configservice | awsJson1_1 | 102 |
| connect-contact-lens | Connect Contact Lens | connectcontactlens | restJson1 | 1 |
| connect | Connect | connect | restJson1 | 404 |
| connectcampaigns | ConnectCampaigns | connectcampaigns | restJson1 | 22 |
| connectcampaignsv2 | ConnectCampaignsV2 | connectcampaignsv2 | restJson1 | 37 |
| connectcases | ConnectCases | connectcases | restJson1 | 43 |
| connecthealth | ConnectHealth | connecthealth | restJson1 | 16 |
| connectparticipant | ConnectParticipant | connectparticipant | restJson1 | 11 |
| continuum | Continuum | continuum | restJson1 | 33 |
| controlcatalog | ControlCatalog | controlcatalog | restJson1 | 6 |
| controltower | ControlTower | controltower | restJson1 | 28 |
| cost-and-usage-report-service | Cost and Usage Report Service | costandusagereportservice | awsJson1_1 | 7 |
| cost-explorer | Cost Explorer | costexplorer | awsJson1_1 | 47 |
| cost-optimization-hub | Cost Optimization Hub | costoptimizationhub | awsJson1_0 | 8 |
| customer-profiles | Customer Profiles | customerprofiles | restJson1 | 115 |
| data-pipeline | Data Pipeline | datapipeline | awsJson1_1 | 19 |
| database-migration-service | Database Migration Service | databasemigrationservice | awsJson1_1 | 119 |
| databrew | DataBrew | databrew | restJson1 | 44 |
| dataexchange | DataExchange | dataexchange | restJson1 | 37 |
| datasync | DataSync | datasync | awsJson1_1 | 53 |
| datazone | DataZone | datazone | restJson1 | 195 |
| dax | DAX | dax | awsJson1_1 | 21 |
| deadline | deadline | deadline | restJson1 | 127 |
| detective | Detective | detective | restJson1 | 29 |
| device-farm | Device Farm | devicefarm | awsJson1_1 | 77 |
| devops-agent | DevOps Agent | devopsagent | restJson1 | 63 |
| devops-guru | DevOps Guru | devopsguru | restJson1 | 31 |
| direct-connect | Direct Connect | directconnect | awsJson1_1 | 73 |
| directory-service-data | Directory Service Data | directoryservicedata | restJson1 | 17 |
| directory-service | Directory Service | directoryservice | awsJson1_1 | 80 |
| dlm | DLM | dlm | restJson1 | 8 |
| docdb-elastic | DocDB Elastic | docdbelastic | restJson1 | 19 |
| docdb | DocDB | docdb | awsQuery | 56 |
| drs | drs | drs | restJson1 | 70 |
| dsql | DSQL | dsql | restJson1 | 16 |
| dynamodb-streams | DynamoDB Streams | dynamodbstreams | awsJson1_0 | 4 |
| dynamodb | DynamoDB | dynamodb | awsJson1_0 | 58 |
| ebs | EBS | ebs | restJson1 | 6 |
| ec2-instance-connect | EC2 Instance Connect | ec2instanceconnect | awsJson1_1 | 2 |
| ec2 | EC2 | ec2 | ec2Query | 811 |
| ecr-public | ECR PUBLIC | ecrpublic | awsJson1_1 | 23 |
| ecr | ECR | ecr | awsJson1_1 | 62 |
| ecs | ECS | ecs | awsJson1_1 | 88 |
| efs | EFS | efs | restJson1 | 31 |
| eks-auth | EKS Auth | eksauth | restJson1 | 1 |
| eks | EKS | eks | restJson1 | 70 |
| elastic-beanstalk | Elastic Beanstalk | elasticbeanstalk | awsQuery | 47 |
| elastic-load-balancing-v2 | Elastic Load Balancing v2 | elasticloadbalancingv2 | awsQuery | 51 |
| elastic-load-balancing | Elastic Load Balancing | elasticloadbalancing | awsQuery | 29 |
| elasticache | ElastiCache | elasticache | awsQuery | 77 |
| elasticsearch-service | Elasticsearch Service | elasticsearchservice | restJson1 | 51 |
| elementalinference | ElementalInference | elementalinference | restJson1 | 24 |
| emr-containers | EMR containers | emrcontainers | restJson1 | 25 |
| emr-serverless | EMR Serverless | emrserverless | restJson1 | 22 |
| emr | EMR | emr | awsJson1_1 | 65 |
| endusermessaging | EndUserMessaging | endusermessaging | restJson1 | 27 |
| entityresolution | EntityResolution | entityresolution | restJson1 | 38 |
| eventbridge | EventBridge | eventbridge | awsJson1_1 | 57 |
| eventbridgev2 | EventBridgeV2 | eventbridgev2 | rpcv2Cbor | 25 |
| evs | evs | evs | awsJson1_0 | 24 |
| firehose | Firehose | firehose | awsJson1_1 | 12 |
| fis | fis | fis | restJson1 | 26 |
| fms | FMS | fms | awsJson1_1,rpcv2Cbor | 42 |
| forecast | forecast | forecast | awsJson1_1 | 63 |
| forecastquery | forecastquery | forecastquery | awsJson1_1 | 2 |
| frauddetector | FraudDetector | frauddetector | awsJson1_1 | 73 |
| freetier | FreeTier | freetier | awsJson1_0 | 5 |
| fsx | FSx | fsx | awsJson1_1 | 48 |
| gamelift | GameLift | gamelift | awsJson1_1,rpcv2Cbor | 120 |
| gameliftstreams | GameLiftStreams | gameliftstreams | restJson1 | 30 |
| geo-maps | Geo Maps | geomaps | restJson1 | 5 |
| geo-places | Geo Places | geoplaces | restJson1 | 7 |
| geo-routes | Geo Routes | georoutes | restJson1 | 5 |
| glacier | Glacier | glacier | restJson1 | 33 |
| global-accelerator | Global Accelerator | globalaccelerator | awsJson1_1 | 56 |
| glue | Glue | glue | awsJson1_1 | 306 |
| grafana | grafana | grafana | restJson1 | 25 |
| greengrass | Greengrass | greengrass | restJson1 | 92 |
| greengrassv2 | GreengrassV2 | greengrassv2 | restJson1 | 29 |
| groundstation | GroundStation | groundstation | restJson1 | 40 |
| guardduty | GuardDuty | guardduty | restJson1 | 102 |
| health | Health | health | awsJson1_1,rpcv2Cbor | 15 |
| healthlake | HealthLake | healthlake | awsJson1_0 | 31 |
| iam-toolbox | IAM Toolbox | iamtoolbox | restJson1 | 1 |
| iam | IAM | iam | awsQuery | 180 |
| identitystore | identitystore | identitystore | awsJson1_1 | 22 |
| imagebuilder | imagebuilder | imagebuilder | restJson1 | 77 |
| inspector-scan | Inspector Scan | inspectorscan | restJson1 | 1 |
| inspector | Inspector | inspector | awsJson1_1 | 37 |
| inspector2 | Inspector2 | inspector2 | restJson1 | 84 |
| interconnect | Interconnect | interconnect | awsJson1_0,rpcv2Cbor | 13 |
| internetmonitor | InternetMonitor | internetmonitor | restJson1 | 16 |
| invoicing | Invoicing | invoicing | awsJson1_0 | 21 |
| iot-data-plane | IoT Data Plane | iotdataplane | restJson1 | 11 |
| iot-jobs-data-plane | IoT Jobs Data Plane | iotjobsdataplane | restJson1 | 5 |
| iot-managed-integrations | IoT Managed Integrations | iotmanagedintegrations | restJson1 | 83 |
| iot-wireless | IoT Wireless | iotwireless | restJson1 | 112 |
| iot | IoT | iot | restJson1 | 272 |
| iotdeviceadvisor | IotDeviceAdvisor | iotdeviceadvisor | restJson1 | 14 |
| iotfleetwise | IoTFleetWise | iotfleetwise | awsJson1_0 | 57 |
| iotsecuretunneling | IoTSecureTunneling | iotsecuretunneling | awsJson1_1 | 8 |
| iotsitewise | IoTSiteWise | iotsitewise | restJson1 | 149 |
| iotthingsgraph | IoTThingsGraph | iotthingsgraph | awsJson1_1 | 35 |
| iottwinmaker | IoTTwinMaker | iottwinmaker | restJson1 | 40 |
| ivs-realtime | IVS RealTime | ivsrealtime | restJson1 | 40 |
| ivs | ivs | ivs | restJson1 | 46 |
| ivschat | ivschat | ivschat | restJson1 | 17 |
| kafka | Kafka | kafka | restJson1 | 64 |
| kafkaconnect | KafkaConnect | kafkaconnect | restJson1 | 21 |
| kendra-ranking | Kendra Ranking | kendraranking | awsJson1_0,rpcv2Cbor | 9 |
| kendra | kendra | kendra | awsJson1_1 | 66 |
| keyspaces | Keyspaces | keyspaces | awsJson1_0,rpcv2Cbor | 19 |
| keyspacesstreams | KeyspacesStreams | keyspacesstreams | awsJson1_0 | 4 |
| kinesis-analytics-v2 | Kinesis Analytics V2 | kinesisanalyticsv2 | awsJson1_1 | 33 |
| kinesis-analytics | Kinesis Analytics | kinesisanalytics | awsJson1_1 | 20 |
| kinesis-video-archived-media | Kinesis Video Archived Media | kinesisvideoarchivedmedia | restJson1 | 6 |
| kinesis-video-media | Kinesis Video Media | kinesisvideomedia | restJson1 | 1 |
| kinesis-video-signaling | Kinesis Video Signaling | kinesisvideosignaling | restJson1 | 2 |
| kinesis-video-webrtc-storage | Kinesis Video WebRTC Storage | kinesisvideowebrtcstorage | restJson1 | 2 |
| kinesis-video | Kinesis Video | kinesisvideo | restJson1 | 32 |
| kinesis | Kinesis | kinesis | awsJson1_1 | 45 |
| kms | KMS | kms | awsJson1_1 | 56 |
| lakeformation | LakeFormation | lakeformation | restJson1 | 69 |
| lambda-core | Lambda Core | lambdacore | restJson1 | 6 |
| lambda-microvms | Lambda Microvms | lambdamicrovms | restJson1 | 24 |
| lambda-web | Lambda Web | lambdaweb | restJson1 | 20 |
| lambda | Lambda | lambda | restJson1 | 88 |
| launch-wizard | Launch Wizard | launchwizard | restJson1 | 15 |
| lex-model-building-service | Lex Model Building Service | lexmodelbuildingservice | restJson1 | 42 |
| lex-models-v2 | Lex Models V2 | lexmodelsv2 | restJson1 | 107 |
| lex-runtime-service | Lex Runtime Service | lexruntimeservice | restJson1 | 5 |
| lex-runtime-v2 | Lex Runtime V2 | lexruntimev2 | restJson1 | 6 |
| license-manager-linux-subscriptions | License Manager Linux Subscriptions | licensemanagerlinuxsubscriptions | restJson1 | 11 |
| license-manager-user-subscriptions | License Manager User Subscriptions | licensemanagerusersubscriptions | restJson1 | 17 |
| license-manager | License Manager | licensemanager | awsJson1_1 | 62 |
| lightsail | Lightsail | lightsail | awsJson1_1 | 162 |
| location | Location | location | restJson1 | 64 |
| lookoutequipment | LookoutEquipment | lookoutequipment | awsJson1_0 | 49 |
| m2 | m2 | m2 | restJson1 | 37 |
| machine-learning | Machine Learning | machinelearning | awsJson1_1 | 28 |
| macie2 | Macie2 | macie2 | restJson1 | 81 |
| mailmanager | MailManager | mailmanager | awsJson1_0,rpcv2Cbor | 60 |
| managedblockchain-query | ManagedBlockchain Query | managedblockchainquery | restJson1 | 9 |
| managedblockchain | ManagedBlockchain | managedblockchain | restJson1 | 27 |
| marketplace-agreement | Marketplace Agreement | marketplaceagreement | awsJson1_0,rpcv2Cbor | 25 |
| marketplace-catalog | Marketplace Catalog | marketplacecatalog | restJson1 | 15 |
| marketplace-commerce-analytics | Marketplace Commerce Analytics | marketplacecommerceanalytics | awsJson1_1 | 2 |
| marketplace-deployment | Marketplace Deployment | marketplacedeployment | restJson1 | 4 |
| marketplace-discovery | Marketplace Discovery | marketplacediscovery | restJson1 | 9 |
| marketplace-entitlement-service | Marketplace Entitlement Service | marketplaceentitlementservice | awsJson1_1,rpcv2Cbor | 1 |
| marketplace-metering | Marketplace Metering | marketplacemetering | awsJson1_1 | 4 |
| marketplace-reporting | Marketplace Reporting | marketplacereporting | restJson1 | 1 |
| mediaconnect | MediaConnect | mediaconnect | restJson1 | 96 |
| mediaconvert | MediaConvert | mediaconvert | restJson1 | 34 |
| medialive | MediaLive | medialive | restJson1 | 123 |
| mediapackage-vod | MediaPackage Vod | mediapackagevod | restJson1 | 17 |
| mediapackage | MediaPackage | mediapackage | restJson1 | 19 |
| mediapackagev2 | MediaPackageV2 | mediapackagev2 | restJson1 | 30 |
| mediastore-data | MediaStore Data | mediastoredata | restJson1 | 5 |
| mediastore | MediaStore | mediastore | awsJson1_1 | 21 |
| mediatailor | MediaTailor | mediatailor | restJson1 | 48 |
| medical-imaging | Medical Imaging | medicalimaging | restJson1 | 18 |
| memorydb | MemoryDB | memorydb | awsJson1_1 | 45 |
| mgn | mgn | mgn | restJson1 | 95 |
| migration-hub-refactor-spaces | Migration Hub Refactor Spaces | migrationhubrefactorspaces | restJson1 | 24 |
| migration-hub | Migration Hub | migrationhub | awsJson1_1 | 21 |
| migrationhub-config | MigrationHub Config | migrationhubconfig | awsJson1_1 | 4 |
| migrationhuborchestrator | MigrationHubOrchestrator | migrationhuborchestrator | restJson1 | 31 |
| migrationhubstrategy | MigrationHubStrategy | migrationhubstrategy | restJson1 | 22 |
| mpa | MPA | mpa | restJson1 | 22 |
| mq | mq | mq | restJson1 | 25 |
| mturk | MTurk | mturk | awsJson1_1 | 39 |
| mwaa-serverless | MWAA Serverless | mwaaserverless | awsJson1_0 | 15 |
| mwaa | MWAA | mwaa | restJson1 | 12 |
| neptune-graph | Neptune Graph | neptunegraph | restJson1 | 34 |
| neptune | Neptune | neptune | awsQuery | 70 |
| neptunedata | neptunedata | neptunedata | restJson1 | 48 |
| network-firewall | Network Firewall | networkfirewall | awsJson1_0 | 85 |
| network-security-manager | Network Security Manager | networksecuritymanager | restJson1 | 46 |
| networkflowmonitor | NetworkFlowMonitor | networkflowmonitor | restJson1 | 25 |
| networkmanager | NetworkManager | networkmanager | restJson1 | 97 |
| networkmonitor | NetworkMonitor | networkmonitor | restJson1 | 12 |
| notifications | Notifications | notifications | restJson1 | 40 |
| notificationscontacts | NotificationsContacts | notificationscontacts | restJson1 | 9 |
| nova-act | Nova Act | novaact | restJson1 | 16 |
| oam | OAM | oam | restJson1 | 15 |
| observabilityadmin | ObservabilityAdmin | observabilityadmin | restJson1 | 45 |
| odb | odb | odb | awsJson1_0 | 81 |
| omics | Omics | omics | restJson1 | 107 |
| opensearch | OpenSearch | opensearch | restJson1 | 102 |
| opensearchserverless | OpenSearchServerless | opensearchserverless | awsJson1_0 | 54 |
| organizations | Organizations | organizations | awsJson1_1 | 63 |
| osis | OSIS | osis | restJson1 | 22 |
| outposts | Outposts | outposts | restJson1 | 45 |
| partnercentral-account | PartnerCentral Account | partnercentralaccount | awsJson1_0 | 34 |
| partnercentral-benefits | PartnerCentral Benefits | partnercentralbenefits | awsJson1_0 | 17 |
| partnercentral-channel | PartnerCentral Channel | partnercentralchannel | awsJson1_0 | 17 |
| partnercentral-revenue-measurement | PartnerCentral Revenue Measurement | partnercentralrevenuemeasurement | rpcv2Cbor | 18 |
| partnercentral-selling | PartnerCentral Selling | partnercentralselling | awsJson1_0 | 45 |
| payment-cryptography-data | Payment Cryptography Data | paymentcryptographydata | restJson1 | 15 |
| payment-cryptography | Payment Cryptography | paymentcryptography | awsJson1_0 | 32 |
| pca-connector-ad | Pca Connector Ad | pcaconnectorad | restJson1 | 25 |
| pca-connector-scep | Pca Connector Scep | pcaconnectorscep | restJson1 | 12 |
| pcs | PCS | pcs | awsJson1_0 | 19 |
| personalize-events | Personalize Events | personalizeevents | restJson1 | 5 |
| personalize-runtime | Personalize Runtime | personalizeruntime | restJson1 | 3 |
| personalize | Personalize | personalize | awsJson1_1 | 71 |
| pi | PI | pi | awsJson1_1,rpcv2Cbor | 14 |
| pinpoint-email | Pinpoint Email | pinpointemail | restJson1 | 42 |
| pinpoint-sms-voice-v2 | Pinpoint SMS Voice V2 | pinpointsmsvoicev2 | awsJson1_0 | 110 |
| pinpoint-sms-voice | Pinpoint SMS Voice | pinpointsmsvoice | restJson1 | 8 |
| pinpoint | Pinpoint | pinpoint | restJson1 | 122 |
| pipes | Pipes | pipes | restJson1 | 10 |
| polly | Polly | polly | restJson1 | 10 |
| pricing-plan-manager | Pricing Plan Manager | pricingplanmanager | restJson1 | 9 |
| pricing | Pricing | pricing | awsJson1_1 | 5 |
| proton | Proton | proton | awsJson1_0 | 87 |
| qapps | QApps | qapps | restJson1 | 35 |
| qbusiness | QBusiness | qbusiness | restJson1 | 83 |
| qconnect | QConnect | qconnect | restJson1 | 94 |
| quicksight | QuickSight | quicksight | restJson1 | 299 |
| ram | RAM | ram | restJson1 | 35 |
| rbin | rbin | rbin | restJson1 | 10 |
| rds-data | RDS Data | rdsdata | restJson1 | 6 |
| rds | RDS | rds | awsQuery | 168 |
| redshift-data | Redshift Data | redshiftdata | awsJson1_1 | 12 |
| redshift-serverless | Redshift Serverless | redshiftserverless | awsJson1_1 | 65 |
| redshift | Redshift | redshift | awsQuery | 145 |
| rekognition | Rekognition | rekognition | awsJson1_1 | 75 |
| repostspace | repostspace | repostspace | restJson1 | 19 |
| resiliencehub | resiliencehub | resiliencehub | restJson1 | 63 |
| resiliencehubv2 | resiliencehubv2 | resiliencehubv2 | restJson1 | 73 |
| resource-explorer-2 | Resource Explorer 2 | resourceexplorer2 | restJson1 | 32 |
| resource-groups-tagging-api | Resource Groups Tagging API | resourcegroupstaggingapi | awsJson1_1 | 9 |
| resource-groups | Resource Groups | resourcegroups | restJson1 | 23 |
| rolesanywhere | RolesAnywhere | rolesanywhere | restJson1 | 30 |
| route-53-domains | Route 53 Domains | route53domains | awsJson1_1 | 35 |
| route-53 | Route 53 | route53 | restXml | 71 |
| route53-recovery-cluster | Route53 Recovery Cluster | route53recoverycluster | awsJson1_0 | 4 |
| route53-recovery-control-config | Route53 Recovery Control Config | route53recoverycontrolconfig | restJson1 | 25 |
| route53-recovery-readiness | Route53 Recovery Readiness | route53recoveryreadiness | restJson1 | 32 |
| route53globalresolver | Route53GlobalResolver | route53globalresolver | restJson1 | 48 |
| route53profiles | Route53Profiles | route53profiles | restJson1 | 16 |
| route53resolver | Route53Resolver | route53resolver | awsJson1_1 | 72 |
| rtbfabric | RTBFabric | rtbfabric | restJson1 | 36 |
| rum | RUM | rum | restJson1 | 20 |
| s3-control | S3 Control | s3control | restXml | 97 |
| s3 | S3 | s3 | restXml | 112 |
| s3files | S3Files | s3files | restJson1 | 21 |
| s3outposts | S3Outposts | s3outposts | restJson1 | 5 |
| s3tables | S3Tables | s3tables | restJson1 | 49 |
| s3vectors | S3Vectors | s3vectors | restJson1 | 21 |
| sagemaker-a2i-runtime | SageMaker A2I Runtime | sagemakera2iruntime | restJson1 | 5 |
| sagemaker-edge | Sagemaker Edge | sagemakeredge | restJson1 | 3 |
| sagemaker-featurestore-runtime | SageMaker FeatureStore Runtime | sagemakerfeaturestoreruntime | restJson1 | 7 |
| sagemaker-geospatial | SageMaker Geospatial | sagemakergeospatial | restJson1 | 19 |
| sagemaker-metrics | SageMaker Metrics | sagemakermetrics | restJson1 | 2 |
| sagemaker-runtime-http2 | SageMaker Runtime HTTP2 | sagemakerruntimehttp2 | restJson1 | 1 |
| sagemaker-runtime | SageMaker Runtime | sagemakerruntime | restJson1 | 3 |
| sagemaker | SageMaker | sagemaker | awsJson1_1 | 409 |
| sagemakerjobruntime | SagemakerJobRuntime | sagemakerjobruntime | restJson1 | 4 |
| sagemakertrainingsessionruntime | SageMakerTrainingSessionRuntime | sagemakertrainingsessionruntime | restJson1 | 6 |
| savingsplans | savingsplans | savingsplans | restJson1 | 10 |
| scheduler | Scheduler | scheduler | restJson1 | 12 |
| schemas | schemas | schemas | restJson1 | 31 |
| secrets-manager | Secrets Manager | secretsmanager | awsJson1_1 | 23 |
| security-ir | Security IR | securityir | restJson1 | 25 |
| securityagent | SecurityAgent | securityagent | restJson1 | 96 |
| securityhub | SecurityHub | securityhub | restJson1 | 123 |
| securitylake | SecurityLake | securitylake | restJson1 | 31 |
| serverlessapplicationrepository | ServerlessApplicationRepository | serverlessapplicationrepository | restJson1 | 14 |
| service-catalog-appregistry | Service Catalog AppRegistry | servicecatalogappregistry | restJson1 | 24 |
| service-catalog | Service Catalog | servicecatalog | awsJson1_1 | 90 |
| service-quotas | Service Quotas | servicequotas | awsJson1_1 | 26 |
| servicediscovery | ServiceDiscovery | servicediscovery | awsJson1_1 | 30 |
| ses | SES | ses | awsQuery | 71 |
| sesv2 | SESv2 | sesv2 | restJson1 | 116 |
| sfn | SFN | sfn | awsJson1_0 | 37 |
| shield | Shield | shield | awsJson1_1 | 36 |
| signer-data | Signer Data | signerdata | restJson1 | 1 |
| signer | signer | signer | restJson1 | 19 |
| signin | Signin | signin | restJson1 | 12 |
| simpledbv2 | SimpleDBv2 | simpledbv2 | restJson1 | 3 |
| snow-device-management | Snow Device Management | snowdevicemanagement | restJson1 | 13 |
| snowball | Snowball | snowball | awsJson1_1,rpcv2Cbor | 27 |
| sns | SNS | sns | awsQuery | 42 |
| socialmessaging | SocialMessaging | socialmessaging | restJson1 | 38 |
| sqs | SQS | sqs | awsJson1_0,awsQueryCompatible | 23 |
| ssm-contacts | SSM Contacts | ssmcontacts | awsJson1_1 | 39 |
| ssm-guiconnect | SSM GuiConnect | ssmguiconnect | restJson1 | 3 |
| ssm-incidents | SSM Incidents | ssmincidents | restJson1 | 31 |
| ssm-quicksetup | SSM QuickSetup | ssmquicksetup | restJson1 | 14 |
| ssm-sap | Ssm Sap | ssmsap | restJson1 | 27 |
| ssm | SSM | ssm | awsJson1_1 | 152 |
| sso-admin | SSO Admin | ssoadmin | awsJson1_1 | 79 |
| sso-oidc | SSO OIDC | ssooidc | restJson1 | 4 |
| sso | SSO | sso | restJson1 | 4 |
| storage-gateway | Storage Gateway | storagegateway | awsJson1_1 | 96 |
| sts | STS | sts | awsQuery | 11 |
| supplychain | SupplyChain | supplychain | restJson1 | 30 |
| support-app | Support App | supportapp | restJson1 | 10 |
| support | Support | support | awsJson1_1 | 20 |
| supportauthz | SupportAuthZ | supportauthz | restJson1 | 11 |
| sustainability | Sustainability | sustainability | restJson1 | 4 |
| swf | SWF | swf | awsJson1_0 | 39 |
| synthetics | synthetics | synthetics | restJson1 | 22 |
| taxsettings | TaxSettings | taxsettings | restJson1 | 16 |
| textract | Textract | textract | awsJson1_1 | 25 |
| timestream-influxdb | Timestream InfluxDB | timestreaminfluxdb | awsJson1_0 | 24 |
| timestream-query | Timestream Query | timestreamquery | awsJson1_0 | 15 |
| timestream-write | Timestream Write | timestreamwrite | awsJson1_0 | 19 |
| transcribe-streaming | Transcribe Streaming | transcribestreaming | restJson1 | 5 |
| transcribe | Transcribe | transcribe | awsJson1_1 | 44 |
| transfer | Transfer | transfer | awsJson1_1 | 71 |
| translate | Translate | translate | awsJson1_1,rpcv2Cbor | 19 |
| trustedadvisor | TrustedAdvisor | trustedadvisor | restJson1 | 12 |
| uxc | uxc | uxc | restJson1 | 3 |
| verifiedpermissions | VerifiedPermissions | verifiedpermissions | awsJson1_0 | 34 |
| voice-id | Voice ID | voiceid | awsJson1_0 | 29 |
| vpc-lattice | VPC Lattice | vpclattice | restJson1 | 73 |
| waf-regional | WAF Regional | wafregional | awsJson1_1 | 81 |
| waf | WAF | waf | awsJson1_1 | 77 |
| wafv2 | WAFV2 | wafv2 | awsJson1_1 | 59 |
| wellarchitected | WellArchitected | wellarchitected | restJson1 | 95 |
| wickr | Wickr | wickr | restJson1 | 44 |
| wisdom | Wisdom | wisdom | restJson1 | 41 |
| workdocs | WorkDocs | workdocs | restJson1 | 44 |
| workmail | WorkMail | workmail | awsJson1_1 | 92 |
| workmailmessageflow | WorkMailMessageFlow | workmailmessageflow | restJson1 | 2 |
| workspaces-instances | Workspaces Instances | workspacesinstances | awsJson1_0,rpcv2Cbor | 14 |
| workspaces-thin-client | WorkSpaces Thin Client | workspacesthinclient | restJson1 | 16 |
| workspaces-web | WorkSpaces Web | workspacesweb | restJson1 | 75 |
| workspaces | WorkSpaces | workspaces | awsJson1_1 | 91 |
| xray | XRay | xray | restJson1 | 38 |
