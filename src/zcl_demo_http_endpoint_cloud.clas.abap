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
    TYPES  BEGIN OF ty_header_uuid.
    TYPES:   uuid TYPE sysuuid_x16.
             INCLUDE TYPE I_SalesOrderTP.
    TYPES  END OF ty_header_uuid.

    TYPES  BEGIN OF tt_items_uuid.
    TYPES:   uuid TYPE sysuuid_x16.
             INCLUDE TYPE I_SalesOrderItemTP.
    TYPES  END OF tt_items_uuid.

    TYPES  BEGIN OF tt_partners_uuid.
    TYPES:   uuid_ref TYPE sysuuid_x16.
             INCLUDE TYPE I_SalesOrderItemPartnerTP.
    TYPES  END OF tt_partners_uuid.

    TYPES  BEGIN OF tt_pricing_elements_uuid.
    TYPES:   uuid_ref TYPE sysuuid_x16.
             INCLUDE TYPE I_SalesOrderItemPrcgElmntTP.
    TYPES  END OF tt_pricing_elements_uuid.

    TYPES  BEGIN OF tt_schedule_lines_uuid.
    TYPES:   uuid_ref TYPE sysuuid_x16.
             INCLUDE TYPE I_SalesOrderScheduleLineTP.
    TYPES  END OF tt_schedule_lines_uuid.

    TYPES tt_items            TYPE STANDARD TABLE OF tt_items_uuid WITH DEFAULT KEY.
    TYPES tt_partners         TYPE STANDARD TABLE OF tt_partners_uuid WITH DEFAULT KEY.
    TYPES tt_pricing_elements TYPE STANDARD TABLE OF tt_pricing_elements_uuid WITH DEFAULT KEY.
    TYPES tt_schedule_lines   TYPE STANDARD TABLE OF tt_schedule_lines_uuid WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_so_create_rap_bo_multiple,
             SalesOrderHeader             TYPE ty_header_uuid,
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
    METHODS _create_s_ord_via_rap_bo_mult IMPORTING is_sales_order_payload_rap_bo    TYPE ty_so_create_rap_bo_multiple
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
            DATA(lv_created_sales_order_no) = _create_s_ord_via_rap_bo_mult( ls_sales_ord_payload_rap_bo_ml ).
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

  METHOD _create_s_ord_via_rap_bo_mult.
    DATA ls_so_temp_key TYPE STRUCTURE FOR KEY OF I_SalesOrderTP.

    " === PROCESS HEADER, ITEMS, PARTNERS, PRICING, SCHEDULES ===
    DATA(ls_so_header) = is_sales_order_payload_rap_bo-salesorderheader.
    DATA(lt_items)     = is_sales_order_payload_rap_bo-salesorderitem.
    DATA(lt_partners)  = is_sales_order_payload_rap_bo-salesorderitempartner.
    DATA(lt_pricing)   = is_sales_order_payload_rap_bo-salesorderitempricingelement.
    DATA(lt_schedules) = is_sales_order_payload_rap_bo-salesorderitemscheduleline.

    DATA(top_index)  = 0.

    " === UUID assignment ===
    ls_so_header-uuid = xco_cp=>uuid( )->value.

    LOOP AT lt_items REFERENCE INTO DATA(lrt_items_deep).
      top_index += 1.

      LOOP AT lrt_items_deep->* REFERENCE INTO DATA(lr_item_deep).
        " Generate UUID for item
        lr_item_deep->uuid = xco_cp=>uuid( )->value.

        " === Update Partner UUID_REFs for this item ===
        LOOP AT lt_partners[ top_index ] ASSIGNING FIELD-SYMBOL(<fs_partner>).
          <fs_partner>-uuid_ref = lr_item_deep->uuid.
        ENDLOOP.

        " === Update Pricing UUID_REFs for this item ===
        LOOP AT lt_pricing[ top_index ] ASSIGNING FIELD-SYMBOL(<fs_pricing>).
          <fs_pricing>-uuid_ref = lr_item_deep->uuid.
        ENDLOOP.

        " === Update Schedule Line UUID_REFs for this item ===
        LOOP AT lt_schedules[ top_index ] ASSIGNING FIELD-SYMBOL(<fs_schedule>).
          <fs_schedule>-uuid_ref = lr_item_deep->uuid.
        ENDLOOP.

      ENDLOOP.
    ENDLOOP.

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
           WITH VALUE #( ( %cid  = ls_so_header-uuid
                           %data = CORRESPONDING #( ls_so_header ) ) )
           " ----------- CREATE ITEMS -----------
           CREATE BY \_Item
           FIELDS ( Product
                    Plant
                    RequestedQuantity
                    RequestedQuantityUnit )
           WITH VALUE #( FOR <items> IN lt_items INDEX INTO lv_items_index
                         ( %cid_ref   = ls_so_header-uuid  " references header
                           SalesOrder = space
                           %target    = VALUE #( FOR <item> IN <items>
                                                 ( %cid                  = <item>-Uuid
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
                         LET lv_uuid    = xco_cp=>uuid( )->value
                             ls_partner = lt_partners[ i ][ j ] IN
                         ( %cid_ref       = ls_partner-uuid_ref   " always referencing item
                           salesorder     = space
                           salesorderitem = space
                           %target        = VALUE #( ( %cid                   = xco_cp=>uuid( )->value " this here must always be unique, otherwise 'not unique DUMP'
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
                         ( %cid_ref       = ls_price-uuid_ref " referencing item
                           salesorder     = space
                           salesorderitem = space
                           %target        = VALUE #( ( %cid                         = xco_cp=>uuid( )->value
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
               ( %cid_ref       = ls_sched-uuid_ref " referencing item
                 salesorder     = space
                 salesorderitem = space
                 %target        = VALUE #( ( %cid                      = xco_cp=>uuid( )->value
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
ENDCLASS.
