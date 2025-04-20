CLASS zcl_demo_http_endpoint_cloud DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_service_extension.

    " For single processing
    TYPES: BEGIN OF ty_so_create_rap_bo,
             SalesOrderHeader             TYPE I_SalesOrderTP,
             SalesOrderItem               TYPE I_SalesOrderItemTP,
             SalesOrderItemPartner        TYPE I_SalesOrderItemPartnerTP,
             SalesOrderItemPricingElement TYPE I_SalesOrderItemPrcgElmntTP,
             SalesOrderItemScheduleLine   TYPE I_SalesOrderScheduleLineTP,
           END OF ty_so_create_rap_bo.

    " For multiple processing
    TYPES tt_items            TYPE STANDARD TABLE OF I_SalesOrderItemTP WITH DEFAULT KEY.
    TYPES tt_partners         TYPE STANDARD TABLE OF I_SalesOrderItemPartnerTP WITH DEFAULT KEY.
    TYPES tt_pricing_elements TYPE STANDARD TABLE OF I_SalesOrderItemPrcgElmntTP WITH DEFAULT KEY.
    TYPES tt_schedule_lines   TYPE STANDARD TABLE OF I_SalesOrderScheduleLineTP WITH DEFAULT KEY.
    TYPES: BEGIN OF ty_so_create_rap_bo_multiple,
             SalesOrderHeader             TYPE I_SalesOrderTP,
             SalesOrderItem               TYPE STANDARD TABLE OF tt_items WITH DEFAULT KEY,
             SalesOrderItemPartner        TYPE STANDARD TABLE OF tt_partners WITH DEFAULT KEY,
             SalesOrderItemPricingElement TYPE STANDARD TABLE OF tt_pricing_elements WITH DEFAULT KEY,
             SalesOrderItemScheduleLine   TYPE STANDARD TABLE OF tt_schedule_lines WITH DEFAULT KEY,
           END OF ty_so_create_rap_bo_multiple.

    TYPES ty_created_sales_order_no TYPE I_SalesOrderTP-SalesOrder.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_response_success,
             status     TYPE string,
             salesOrder TYPE I_SalesOrderTP-salesorder,
             message    TYPE string,
           END OF ty_response_success.

    DATA lv_json_payload                TYPE string.
    DATA ls_sales_order_payload_rap_bo  TYPE ty_so_create_rap_bo.
    DATA ls_sales_ord_payload_rap_bo_ml TYPE ty_so_create_rap_bo_multiple.

    METHODS _create_sales_order_via_rap_bo IMPORTING is_sales_order_payload_rap_bo    TYPE ty_so_create_rap_bo
                                           RETURNING VALUE(rv_created_sales_order_no) TYPE ty_created_sales_order_no.

    " Example: how to dynamize of handling provided multiple items, partners, conditions, schedules to create a Sales Ord. w/ RAP Business Object
    METHODS _create_s_ord_rap_bo_mult_v1 IMPORTING is_sales_order_payload_rap_bo    TYPE ty_so_create_rap_bo_multiple
                                         RETURNING VALUE(rv_created_sales_order_no) TYPE ty_created_sales_order_no.

    METHODS _create_s_ord_rap_bo_mult_v2 IMPORTING is_sales_order_payload_rap_bo    TYPE ty_so_create_rap_bo_multiple
                                         RETURNING VALUE(rv_created_sales_order_no) TYPE ty_created_sales_order_no.
ENDCLASS.


CLASS zcl_demo_http_endpoint_cloud IMPLEMENTATION.
  METHOD if_http_service_extension~handle_request.
    CASE request->get_method( ).
*      WHEN 'GET'.

*      WHEN 'PUT'.

*      WHEN 'DELETE'.

      WHEN 'POST'.
        TRY.
            lv_json_payload = request->get_text( ).

            " ========= START - SINGLE PROCESSING =========
            " 1- Deserialize into the RAP Business Object structure
*            /ui2/cl_json=>deserialize( EXPORTING json = lv_json_payload
*                                       CHANGING  data = ls_sales_order_payload_rap_bo ).
*            " Check if Sales Order Type provided as it is mandatory field
*            IF ls_sales_order_payload_rap_bo-salesorderheader-SalesOrderType IS INITIAL.
*              response->set_status( i_code   = 422
*                                    i_reason = 'Unprocessable Entity' ).
*              response->set_text( |"status":"error","message":"Sales Order Type is mandatory field."| ).
*              RETURN.
*            ENDIF.
*            " 2- Create Sales Order via RAP Business Object
*            DATA(lv_created_sales_order_no) = _create_sales_order_via_rap_bo( ls_sales_order_payload_rap_bo ).
            " ========= END   - SINGLE PROCESSING =========

            " ==================================================================================================

            " ========= START - MULTIPLE PROCESSING =========
            " 1- Deserialize into the RAP Business Object structure (provided multiple items, partners, conditions and/or schedules)
            /ui2/cl_json=>deserialize( EXPORTING json = lv_json_payload
                                       CHANGING  data = ls_sales_ord_payload_rap_bo_ml ).
            " Check if Sales Order Type provided as it is mandatory field
            IF ls_sales_ord_payload_rap_bo_ml-salesorderheader-SalesOrderType IS INITIAL.
              response->set_status( i_code   = 422
                                    i_reason = 'Unprocessable Entity' ).
              response->set_text( |"status":"error","message":"Sales Order Type is mandatory field."| ).
              RETURN.
            ENDIF.
            " 2- Create Sales Order via RAP Business Object
*            DATA(lv_created_sales_order_no) = _create_s_ord_rap_bo_mult_v1( ls_sales_ord_payload_rap_bo_ml ).
            DATA(lv_created_sales_order_no) = _create_s_ord_rap_bo_mult_v2( ls_sales_ord_payload_rap_bo_ml ).
            " ========= END   - MULTIPLE PROCESSING =========

            IF lv_created_sales_order_no IS NOT INITIAL.
              DATA(ls_response_success) = VALUE ty_response_success(
                  status     = 'success'
                  salesOrder = lv_created_sales_order_no
                  message    = |Sales Order { lv_created_sales_order_no } created successfully.| ).

              DATA(lv_json_response) = ||.
              lv_json_response = /ui2/cl_json=>serialize( data = ls_response_success ).

              response->set_status( i_code   = 200
                                    i_reason = 'OK' ).
              response->set_text( lv_json_response ).
            ELSE.
              response->set_status( i_code   = 422
                                    i_reason = 'Unprocessable Entity' ).
              response->set_text(
                  |"status":"error","message":"Sales Order could not be created. Check your provided data."| ).
            ENDIF.

          CATCH cx_root INTO DATA(lx).
            response->set_status( i_code   = 500
                                  i_reason = 'Internal Server Error' ).
            response->set_text( |"status":"error","message":"{ lx->get_text( ) }"| ).
        ENDTRY.

      WHEN OTHERS.
        response->set_status( i_code   = 405
                              i_reason = 'Method Not Allowed' ).
        response->set_text( |Only GET-PUT-DELETE-POST supported| ).

    ENDCASE.
  ENDMETHOD.

  METHOD _create_sales_order_via_rap_bo.
    DATA ls_so_temp_key TYPE STRUCTURE FOR KEY OF I_SalesOrderTP.

    DATA(ls_so_header)               = is_sales_order_payload_rap_bo-salesorderheader.
    DATA(ls_so_item)                 = is_sales_order_payload_rap_bo-salesorderitem.
    DATA(ls_so_item_partner)         = is_sales_order_payload_rap_bo-salesorderitempartner.
    DATA(ls_so_item_pricing_element) = is_sales_order_payload_rap_bo-salesorderitempricingelement.
    DATA(ls_so_item_schedule_line)   = is_sales_order_payload_rap_bo-salesorderitemscheduleline.

    " RAP Business Object
    MODIFY ENTITIES OF I_SalesOrderTP
           ENTITY SalesOrder
           CREATE
           FIELDS ( salesordertype
                    salesorganization
                    distributionchannel
                    organizationdivision
                    soldtoparty
                    RequestedDeliveryDate
                    PurchaseOrderByCustomer )
           WITH VALUE #( ( %cid  = 'H001'
                           %data = VALUE #( SalesOrderType          = ls_so_header-SalesOrderType
                                            SalesOrganization       = ls_so_header-SalesOrganization
                                            DistributionChannel     = ls_so_header-DistributionChannel
                                            OrganizationDivision    = ls_so_header-OrganizationDivision
                                            SoldToParty             = ls_so_header-SoldToParty
                                            RequestedDeliveryDate   = ls_so_header-RequestedDeliveryDate
                                            PurchaseOrderByCustomer = ls_so_header-PurchaseOrderByCustomer ) ) )
           " ----------- CREATE ITEM -----------
           CREATE BY \_Item
           FIELDS ( Product
                    Plant
                    RequestedQuantity
                    RequestedQuantityUnit )
           WITH VALUE #( ( %cid_ref   = 'H001' " Points to the header %cid
                           salesorder = space
                           %target    = VALUE #( ( %cid                  = 'I001'
                                                   Product               = ls_so_item-Product
                                                   Plant                 = ls_so_item-Plant
                                                   RequestedQuantity     = ls_so_item-RequestedQuantity
                                                   RequestedQuantityUnit = ls_so_item-RequestedQuantityUnit ) ) ) )
           " ----------- CREATE PARTNER -----------
           ENTITY SalesOrderItem
           CREATE BY \_ItemPartner
           FIELDS ( PartnerFunctionForEdit
                    Customer )
           WITH VALUE #(
               ( %cid_ref       = 'I001' " points that it belongs to item-line with 'I001'
                 SalesOrder     = space
                 SalesOrderItem = space
                 " -> Here for each Customer different %cid, as it must be unique.
                 " -> Otherwise it ends up with dump 'CX_SADL_SHORTDUMP': Content ID 'IP001' is not unique
                 " -> Sames valid also for items above. In case of different items --> different %cid on target level for each entry
                 %target        = VALUE #( ( %cid                   = 'IP001'
                                             Customer               = ls_so_item_partner-Customer
                                             PartnerFunctionForEdit = ls_so_item_partner-PartnerFunctionForEdit )
*                                                     ( %cid     = 'IP002'
*                                                       Customer = ls_so_item_partner-Customer
*                                                       PartnerFunctionForEdit = ls_so_item_partner-PartnerFunctionForEdit )
                                           ) ) )
           " ----------- CREATE PRICING ELEMENT -----------
           ENTITY SalesOrderItem
           CREATE BY \_ItemPricingElement
           FIELDS ( ConditionType
                    ConditionRateAmount
                    ConditionCurrency
                    ConditionQuantity )
           WITH VALUE #( ( %cid_ref       = 'I001' " points that it belongs to item-line with 'I001'
                           SalesOrder     = space
                           SalesOrderItem = space
                           %target        = VALUE #(
                               ( %cid                         = 'IPE001'
                                 ConditionType                = ls_so_item_pricing_element-ConditionType
                                 ConditionRateAmount          = ls_so_item_pricing_element-ConditionRateAmount
                                 ConditionCurrency            = ls_so_item_pricing_element-ConditionCurrency
                                 ConditionQuantity            = ls_so_item_pricing_element-ConditionQuantity
                                 %control-ConditionType       = if_abap_behv=>mk-on
                                 %control-ConditionRateAmount = if_abap_behv=>mk-on
                                 %control-ConditionCurrency   = if_abap_behv=>mk-on
                                 %control-ConditionQuantity   = if_abap_behv=>mk-on ) ) ) )
           " ----------- CREATE SCHEDULE LINE -----------
           ENTITY SalesOrderItem
           CREATE BY \_ScheduleLine
           FIELDS ( RequestedDeliveryDate
                    ScheduleLineOrderQuantity )
           WITH VALUE #( ( %cid_ref       = 'I001' " points that it belongs to item-line with 'I001'
                           SalesOrder     = space
                           SalesOrderItem = space
                           %target        = VALUE #(
                               ( %cid                      = 'SL001'
                                 RequestedDeliveryDate     = ls_so_item_schedule_line-RequestedDeliveryDate
                                 ScheduleLineOrderQuantity = ls_so_item_schedule_line-ScheduleLineOrderQuantity ) ) ) )
           MAPPED   DATA(ls_mapped)
           FAILED   DATA(ls_failed)
           REPORTED DATA(ls_reported).

    " Commit work
    COMMIT ENTITIES BEGIN
           RESPONSE OF i_salesordertp
           FAILED   DATA(ls_save_failed)
           REPORTED DATA(ls_save_reported).

    CONVERT KEY OF i_salesordertp FROM ls_so_temp_key TO DATA(ls_so_final_key).
    " Return created Sales Order Number
    rv_created_sales_order_no = ls_so_final_key-SalesOrder.

    COMMIT ENTITIES END.
  ENDMETHOD.

  METHOD _create_s_ord_rap_bo_mult_v1.
    DATA ls_so_temp_key TYPE STRUCTURE FOR KEY OF I_SalesOrderTP.

    " === PROCESS HEADER, ITEMS, PARTNERS, PRICING, SCHEDULES ===
    DATA(ls_so_header) = is_sales_order_payload_rap_bo-salesorderheader.
    DATA(lt_items)     = is_sales_order_payload_rap_bo-salesorderitem.
    DATA(lt_partners)  = is_sales_order_payload_rap_bo-salesorderitempartner.
    DATA(lt_pricing)   = is_sales_order_payload_rap_bo-salesorderitempricingelement.
    DATA(lt_schedules) = is_sales_order_payload_rap_bo-salesorderitemscheduleline.

    MODIFY ENTITIES OF I_SalesOrderTP
           ENTITY SalesOrder
           CREATE
           FIELDS ( SalesOrderType
                    SalesOrganization
                    DistributionChannel
                    OrganizationDivision
                    SoldToParty
                    RequestedDeliveryDate
                    PurchaseOrderByCustomer )
           WITH VALUE #( ( %cid  = 'H001'
                           %data = VALUE #( SalesOrderType          = ls_so_header-SalesOrderType
                                            SalesOrganization       = ls_so_header-SalesOrganization
                                            DistributionChannel     = ls_so_header-DistributionChannel
                                            OrganizationDivision    = ls_so_header-OrganizationDivision
                                            SoldToParty             = ls_so_header-SoldToParty
                                            RequestedDeliveryDate   = ls_so_header-RequestedDeliveryDate
                                            PurchaseOrderByCustomer = ls_so_header-PurchaseOrderByCustomer ) ) )
           " ----------- CREATE ITEMS -----------
           CREATE BY \_Item
           FIELDS ( Product
                    Plant
                    RequestedQuantity
                    RequestedQuantityUnit )
           WITH VALUE #( FOR <items> IN lt_items INDEX INTO lv_items_index
                         ( %cid_ref   = 'H001'  " references the same 'H001'
                           SalesOrder = space
                           %target    = VALUE #( FOR <item> IN <items>
                                                 ( %cid                  = |I00{ lv_items_index }|
                                                   Product               = <item>-Product
                                                   Plant                 = <item>-Plant
                                                   RequestedQuantity     = <item>-RequestedQuantity
                                                   RequestedQuantityUnit = <item>-RequestedQuantityUnit ) ) ) )
           " ----------- CREATE PARTNERS -----------
           ENTITY SalesOrderItem
           CREATE BY \_ItemPartner
           FIELDS ( PartnerFunctionForEdit
                    Customer )
           WITH VALUE #( FOR i = 1 UNTIL i > lines( lt_partners )
                         FOR j = 1 UNTIL j > lines( lt_partners[ i ] )
                         LET ls_partner = lt_partners[ i ][ j ] IN
                         ( %cid_ref       = |I00{ i }|   " always referencing item {i}
                           salesorder     = space
                           salesorderitem = space
                           %target        = VALUE #( ( %cid                   = |IP00{ i }{ j }| " this here must always be unique, otherwise 'not unique DUMP'
                                                       Customer               = ls_partner-Customer
                                                       PartnerFunctionForEdit = ls_partner-PartnerFunctionForEdit ) ) ) )
           " ----------- CREATE PRICING ELEMENTS -----------
           CREATE BY \_ItemPricingElement
           FIELDS ( ConditionType
                    ConditionRateAmount
                    ConditionCurrency
                    ConditionQuantity )
           WITH VALUE #( FOR i = 1 UNTIL i > lines( lt_pricing )
                         FOR j = 1 UNTIL j > lines( lt_pricing[ i ] )
                         LET ls_price = lt_pricing[ i ][ j ] IN
                         ( %cid_ref       = |I00{ i }| " referencing item
                           salesorder     = space
                           salesorderitem = space
                           %target        = VALUE #( ( %cid                         = |IPE00{ i }{ j }|
                                                       ConditionType                = ls_price-ConditionType
                                                       ConditionRateAmount          = ls_price-ConditionRateAmount
                                                       ConditionCurrency            = ls_price-ConditionCurrency
                                                       ConditionQuantity            = ls_price-ConditionQuantity
                                                       %control-ConditionType       = if_abap_behv=>mk-on
                                                       %control-ConditionRateAmount = if_abap_behv=>mk-on
                                                       %control-ConditionCurrency   = if_abap_behv=>mk-on
                                                       %control-ConditionQuantity   = if_abap_behv=>mk-on ) ) ) )
           " ----------- CREATE SCHEDULE LINES -----------
           CREATE BY \_ScheduleLine
           FIELDS ( RequestedDeliveryDate
                    ScheduleLineOrderQuantity )
           WITH VALUE #(
               FOR i = 1 UNTIL i > lines( lt_schedules )
               FOR j = 1 UNTIL j > lines( lt_schedules[ i ] )
               LET ls_sched = lt_schedules[ i ][ j ] IN
               ( %cid_ref       = |I00{ i }| " referencing item
                 salesorder     = space
                 salesorderitem = space
                 %target        = VALUE #( ( %cid                      = |SL00{ i }{ j }|
                                             RequestedDeliveryDate     = ls_sched-RequestedDeliveryDate
                                             ScheduleLineOrderQuantity = ls_sched-ScheduleLineOrderQuantity ) ) ) )
           MAPPED   DATA(ls_mapped)
           FAILED   DATA(ls_failed)
           REPORTED DATA(ls_reported).

    " Commit work
    COMMIT ENTITIES BEGIN
           RESPONSE OF I_SalesOrderTP
           FAILED   DATA(ls_save_failed)
           REPORTED DATA(ls_save_reported).

    CONVERT KEY OF I_SalesOrderTP FROM ls_so_temp_key TO DATA(ls_so_final_key).
    " Return created Sales Order Number
    rv_created_sales_order_no = ls_so_final_key-SalesOrder.

    COMMIT ENTITIES END.
  ENDMETHOD.

  METHOD _create_s_ord_rap_bo_mult_v2.
    DATA ls_so_temp_key      TYPE STRUCTURE FOR KEY OF I_SalesOrderTP.

    DATA lt_so_header        TYPE TABLE FOR CREATE I_SalesOrderTP.
    DATA lt_items            TYPE TABLE FOR CREATE I_SalesOrderTP\_Item.
    DATA lt_partners         TYPE TABLE FOR CREATE I_SalesOrderItemTP\_ItemPartner.
    DATA lt_pricing_elements TYPE TABLE FOR CREATE I_SalesOrderItemTP\_ItemPricingElement.
    DATA lt_schedule_lines   TYPE TABLE FOR CREATE I_SalesOrderItemTP\_ScheduleLine.

    DATA(data) = is_sales_order_payload_rap_bo.

    " --- Header -------------------------------------------------------
    INSERT VALUE #( %cid                             = xco_cp=>uuid( )->value
                    SalesOrderType                   = data-salesorderheader-SalesOrderType
                    SalesOrganization                = data-salesorderheader-SalesOrganization
                    DistributionChannel              = data-salesorderheader-DistributionChannel
                    OrganizationDivision             = data-salesorderheader-OrganizationDivision
                    SoldToParty                      = data-salesorderheader-SoldToParty
                    RequestedDeliveryDate            = data-salesorderheader-RequestedDeliveryDate
                    PurchaseOrderByCustomer          = data-salesorderheader-PurchaseOrderByCustomer
                    %control-SalesOrderType          = if_abap_behv=>mk-on
                    %control-SalesOrganization       = if_abap_behv=>mk-on
                    %control-DistributionChannel     = if_abap_behv=>mk-on
                    %control-OrganizationDivision    = if_abap_behv=>mk-on
                    %control-SoldToParty             = if_abap_behv=>mk-on
                    %control-RequestedDeliveryDate   = if_abap_behv=>mk-on
                    %control-PurchaseOrderByCustomer = if_abap_behv=>mk-on )
           INTO TABLE lt_so_header
           REFERENCE INTO DATA(lr_header).

    " ------------------------------------------------------------------
    " Create items + dependent entities in one pass
    DATA(external_index) = 0.

    DO lines( data-SalesOrderItem ) TIMES.         " external index

      external_index += 1.                     " 1,2,3,…

      "------------ Item Wrapper
      INSERT VALUE #( %cid_ref = lr_header->%cid )           " Reference to header
             INTO TABLE lt_items
             REFERENCE INTO DATA(lr_item_wrapper).

      LOOP AT data-SalesOrderItem[ external_index ] INTO DATA(ls_item_json).

        INSERT VALUE #( %cid                           = xco_cp=>uuid( )->value
                        Product                        = ls_item_json-Product
                        Plant                          = ls_item_json-Plant
                        RequestedQuantity              = ls_item_json-RequestedQuantity
                        RequestedQuantityUnit          = ls_item_json-RequestedQuantityUnit
                        %control-Product               = if_abap_behv=>mk-on
                        %control-Plant                 = if_abap_behv=>mk-on
                        %control-RequestedQuantity     = if_abap_behv=>mk-on
                        %control-RequestedQuantityUnit = if_abap_behv=>mk-on )
               INTO TABLE lr_item_wrapper->%target
               REFERENCE INTO DATA(lr_item_target).

        "--------- Partner
        INSERT VALUE #( %cid_ref = lr_item_target->%cid )      " Reference to item
               INTO TABLE lt_partners
               REFERENCE INTO DATA(lr_part_wrapper).

        LOOP AT data-SalesOrderItemPartner[ external_index ] INTO DATA(ls_part_json).
          INSERT VALUE #( %cid                            = xco_cp=>uuid( )->value
                          Customer                        = ls_part_json-Customer
                          PartnerFunctionForEdit          = ls_part_json-PartnerFunctionForEdit
                          %control-Customer               = if_abap_behv=>mk-on
                          %control-PartnerFunctionForEdit = if_abap_behv=>mk-on )
                 INTO TABLE lr_part_wrapper->%target.
        ENDLOOP.

        "--------- Pricing Elements
        INSERT VALUE #( %cid_ref = lr_item_target->%cid ) " Reference to item
               INTO TABLE lt_pricing_elements
               REFERENCE INTO DATA(lr_price_wrap).

        LOOP AT data-SalesOrderItemPricingElement[ external_index ] INTO DATA(ls_price_json).

          INSERT VALUE #( %cid                         = xco_cp=>uuid( )->value
                          ConditionType                = ls_price_json-ConditionType
                          ConditionRateAmount          = ls_price_json-ConditionRateAmount
                          ConditionCurrency            = ls_price_json-ConditionCurrency
                          ConditionQuantity            = ls_price_json-ConditionQuantity
                          %control-ConditionType       = if_abap_behv=>mk-on
                          %control-ConditionRateAmount = if_abap_behv=>mk-on
                          %control-ConditionCurrency   = if_abap_behv=>mk-on
                          %control-ConditionQuantity   = if_abap_behv=>mk-on )
                 INTO TABLE lr_price_wrap->%target.
        ENDLOOP.

        "--------- Schedule Lines
        INSERT VALUE #( %cid_ref = lr_item_target->%cid ) " Reference to item
               INTO TABLE lt_schedule_lines
               REFERENCE INTO DATA(lr_schedule_line_wrapper).

        LOOP AT data-SalesOrderItemScheduleLine[ external_index ] INTO DATA(ls_sched_json).

          INSERT VALUE #( %cid                               = xco_cp=>uuid( )->value
                          RequestedDeliveryDate              = ls_sched_json-RequestedDeliveryDate
                          ScheduleLineOrderQuantity          = ls_sched_json-ScheduleLineOrderQuantity
                          %control-RequestedDeliveryDate     = if_abap_behv=>mk-on
                          %control-ScheduleLineOrderQuantity = if_abap_behv=>mk-on  )
                 INTO TABLE lr_schedule_line_wrapper->%target.
        ENDLOOP.

      ENDLOOP.
    ENDDO.

    " EML Call in one Statement
    MODIFY ENTITIES OF I_SalesOrderTP
           ENTITY SalesOrder
           CREATE FROM lt_so_header
           CREATE BY \_Item FROM lt_items
           ENTITY SalesOrderItem
           CREATE BY \_ItemPartner FROM lt_partners
           CREATE BY \_ItemPricingElement FROM lt_pricing_elements
           CREATE BY \_ScheduleLine FROM lt_schedule_lines
           MAPPED   DATA(ls_mapped)
           FAILED   DATA(ls_failed)
           REPORTED DATA(ls_reported).

    " Commit work
    COMMIT ENTITIES BEGIN
           RESPONSE OF I_SalesOrderTP
           FAILED   DATA(ls_save_failed)
           REPORTED DATA(ls_save_reported).

    CONVERT KEY OF I_SalesOrderTP FROM ls_so_temp_key TO DATA(ls_so_final_key).
    " Return created Sales Order Number
    rv_created_sales_order_no = ls_so_final_key-SalesOrder.

    COMMIT ENTITIES END.
  ENDMETHOD.
ENDCLASS.
