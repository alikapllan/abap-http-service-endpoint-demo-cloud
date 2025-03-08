# Demo: ABAP HTTP Service Endpoint for Creating Sales Orders w/ RAP Business Object I_SalesOrderTP 
In another repository I got to the point of HTTP Service Endpoint via [Software-Heroes](https://software-heroes.com/en/sap) and wanted to do a basic example with it and in this regard in [repository (abap-http-service-endpoint-demo)](https://github.com/alikapllan/abap-http-service-endpoint-demo) I implemented the BAPI 'BAPI_SALESORDER_CREATEFROMDAT2' to create a sales order.  

Even though BAPIs are not marked as obsolote by SAP and they still find usage in cloud environments, SAP recommends to replace them with released RAP Business Objects if the relevant SAP System and the business scenario suit. 
   
After suggestion from [Björn - founder of Software Heroes](https://github.com/Xexer) I decided to give it a try with the released RAP BO - I_SalesOrderTP to create sales order as replacement of 'BAPI_SALESORDER_CREATEFROMDAT2'.  

You can reach to [Documentation of I_SalesOrderTP](https://api.sap.com/bointerface/PCE_I_SALESORDERTP) via [SAP Business Accelerator Hub](https://api.sap.com/). It is documented there very understandable.  

# Overview
In our Sandbox system we were able to use the RAP BO I_SalesOrderTP as it was released. The Implemented HTTP Service allows sales order creation via an ABAP-based HTTP endpoint w/ I_SalesOrderTP.  

The service:
- Accepts JSON payload.  
- Deserializes it into based on I_SalesOrderTP structure.
- And finally creates a Sales Order in SAP System if provided JSON payload proper.

# Implementations

## Single-Processing
Firstly, I tried with single processing (structure like) to understand the implementation techniques variations of the I_SalesOrderTP.    

[Here type implementation](https://github.com/alikapllan/abap-http-service-endpoint-demo-cloud/blob/main/src/zcl_demo_http_endpoint_cloud.clas.abap#L8-L15) to handle the single processing    
[Method Definition](https://github.com/alikapllan/abap-http-service-endpoint-demo-cloud/blob/main/src/zcl_demo_http_endpoint_cloud.clas.abap#L37-L38)  
[Method Implementation](https://github.com/alikapllan/abap-http-service-endpoint-demo-cloud/blob/main/src/zcl_demo_http_endpoint_cloud.clas.abap#L117-L224)  
[Method Call](https://github.com/alikapllan/abap-http-service-endpoint-demo-cloud/blob/main/src/zcl_demo_http_endpoint_cloud.clas.abap#L59-L72)  

Here the implementation quite easy as all you have to do is, to pass the deserialized RAP BO parameters to the I_SalesOrderTP.  
> [!WARNING]
> - %cid & %cid_ref is used to mark the connections between entities and this was the part which made me feel a bit confused on the first touch.
> - At the end of save sequence RAP provides us the created Sales Order Number, but we need to convert it to be able to read. To Do this:
>   - We need a [structure for key of I_SalesOrderTP](https://github.com/alikapllan/abap-http-service-endpoint-demo-cloud/blob/main/src/zcl_demo_http_endpoint_cloud.clas.abap#L118)
>   - Then [convert it in the Commit Phase](https://github.com/alikapllan/abap-http-service-endpoint-demo-cloud/blob/main/src/zcl_demo_http_endpoint_cloud.clas.abap#L219-L221) to retrieve the created Sales Order Number.

> [!NOTE]
> **To sum basically:**  
> - Sales order header                   --> has its own %cid (Content ID)   
>   - Item/s                             --> %cid_ref is the %cid of the Sales Order Header  
>     - Partner/s to each Item/s         --> %cid_ref is the %cid of the Item  
>     - Pricing Element/s to each Item/s --> %cid_ref is the %cid of the Item  
>     - Schedule Line/s to each Item/s   --> %cid_ref is the %cid of the Item
 
### Postman Call 
![image](https://github.com/user-attachments/assets/b3fec68d-8b8d-4bae-bf94-542afa43e69a)  

### Created Sales Order
![image](https://github.com/user-attachments/assets/f8e2dfba-2d3b-4d47-89b1-19b3261ab2e8)

### Provided JSON Payload in Postman
> [!IMPORTANT]
> Namings have to match to the CDS entity of I_SalesOrderTP.
```json
{
    "SalesOrderHeader": {
        "SalesOrderType": "ZOR",
        "SalesOrganization": "1010",
        "DistributionChannel": "10",
        "OrganizationDivision": "00",
        "SoldToParty": "0001000001",
        "RequestedDeliveryDate": "20250324",
        "PurchaseOrderByCustomer": "TEST"
    },
    "SalesOrderItem": {
        "Product": "000000000050100006",
        "Plant": "1010",
        "RequestedQuantity": "1",
        "RequestedQuantityUnit": "KG"
    },
    "SalesOrderItemPartner": {
        "Customer": "0001000001",
        "PartnerFunctionForEdit": "AG"
    },
    "SalesOrderItemPricingElement": {
        "ConditionType": "PR00",
        "ConditionRateAmount": "100",
        "ConditionCurrency": "EUR",
        "ConditionQuantity": "1"
    },
    "SalesOrderItemScheduleLine": {
        "RequestedDeliveryDate": "20250324",
        "ScheduleLineOrderQuantity": "1"
    }
}
```


## Multiple-Processing
> [!IMPORTANT]
> Here the challenge was that I needed a nested handling which is why the type definitions were like -> tables in tables for each entity. 

> [!IMPORTANT]
> Another important thing that I faced as a challenge was how to handle the %cid & %cid_ref as they need to be unique and built to create a proper connection between entities.
> 
> In this case I needed a kinda advanced technique which is nested FOR with LET in ABAP to make the %cid_ref unique.
>  - here you can see the applied techniques on entities to manage of handling of the uniqueness of the Content ID & Content ID References.
>     - [Items](https://github.com/alikapllan/abap-http-service-endpoint-demo-cloud/blob/main/src/zcl_demo_http_endpoint_cloud.clas.abap#L254-L268)
>     - [Partners](https://github.com/alikapllan/abap-http-service-endpoint-demo-cloud/blob/main/src/zcl_demo_http_endpoint_cloud.clas.abap#L269-L282)
>     - [Pricing Elements](https://github.com/alikapllan/abap-http-service-endpoint-demo-cloud/blob/main/src/zcl_demo_http_endpoint_cloud.clas.abap#L283-L303)
>     - [Schedule Lines](https://github.com/alikapllan/abap-http-service-endpoint-demo-cloud/blob/main/src/zcl_demo_http_endpoint_cloud.clas.abap#L304-L317)

[Here type implementation](https://github.com/alikapllan/abap-http-service-endpoint-demo-cloud/blob/main/src/zcl_demo_http_endpoint_cloud.clas.abap#L17-L28) to handle the multiple processing    
[Method Definition](https://github.com/alikapllan/abap-http-service-endpoint-demo-cloud/blob/main/src/zcl_demo_http_endpoint_cloud.clas.abap#L40-L42)  
[Method Implementation](https://github.com/alikapllan/abap-http-service-endpoint-demo-cloud/blob/main/src/zcl_demo_http_endpoint_cloud.clas.abap#L226-L333)  
[Method Call](https://github.com/alikapllan/abap-http-service-endpoint-demo-cloud/blob/main/src/zcl_demo_http_endpoint_cloud.clas.abap#L76-L89)  

### Postman Call 
![image](https://github.com/user-attachments/assets/7c4df08f-f897-4b64-8238-2635ce444550)

### Created Sales Order
![image](https://github.com/user-attachments/assets/7ab324f1-87d0-4c7f-9b21-3f239175f4bd)

### Provided JSON Payload in Postman
> [!IMPORTANT]
> Namings have to match to the CDS entity of I_SalesOrderTP.
```json
{
    "SalesOrderHeader": {
        "SalesOrderType": "ZOR",
        "SalesOrganization": "1010",
        "DistributionChannel": "10",
        "OrganizationDivision": "00",
        "SoldToParty": "0001000001",
        "RequestedDeliveryDate": "20250324",
        "PurchaseOrderByCustomer": "TEST"
    },
    "SalesOrderItem": [
        [
            {
                "Product": "000000000050100006",
                "Plant": "1010",
                "RequestedQuantity": "2",
                "RequestedQuantityUnit": "KG"
            }
        ],
        [
            {
                "Product": "000000000050100006",
                "Plant": "1010",
                "RequestedQuantity": "4",
                "RequestedQuantityUnit": "KG"
            }
        ]
    ],
    "SalesOrderItemPartner": [
        [
            {
                "Customer": "0001000001",
                "PartnerFunctionForEdit": "AG"
            },
            {
                "Customer": "0001000001",
                "PartnerFunctionForEdit": "WE"
            }
        ],
        [
            {
                "Customer": "0001000001",
                "PartnerFunctionForEdit": "AG"
            },
            {
                "Customer": "0001000001",
                "PartnerFunctionForEdit": "WE"
            }
        ]
    ],
    "SalesOrderItemPricingElement": [
        [
            {
                "ConditionType": "PR00",
                "ConditionRateAmount": "100",
                "ConditionCurrency": "EUR",
                "ConditionQuantity": "1"
            }
        ],
        [
            {
                "ConditionType": "PR00",
                "ConditionRateAmount": "100",
                "ConditionCurrency": "EUR",
                "ConditionQuantity": "1"
            }
        ]
    ],
    "SalesOrderItemScheduleLine": [
        [
            {
                "RequestedDeliveryDate": "20250324",
                "ScheduleLineOrderQuantity": "1"
            }
        ],
        [
            {
                "RequestedDeliveryDate": "20250324",
                "ScheduleLineOrderQuantity": "1"
            }
        ]
    ]
}
```
