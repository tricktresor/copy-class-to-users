REPORT zt9r_copy_class.

PARAMETERS p_test  AS CHECKBOX       DEFAULT 'X'.
PARAMETERS p_crdev AS CHECKBOX       DEFAULT 'X'.
PARAMETERS p_class TYPE seoclskey    DEFAULT 'ZCL_KOANS_ABOUT_ABAPUNIT'.
PARAMETERS p_newcl TYPE seoclskey    DEFAULT 'ZCL_KOANS_<USER>'.
PARAMETERS p_usrcls TYPE usr02-class DEFAULT 'DEV'.
SELECT-OPTIONS so_user FOR sy-uname.

START-OF-SELECTION.

  PERFORM copy.

FORM copy.
  DATA ls_newcls     TYPE seoclskey.
  DATA lt_class_keys TYPE seoc_class_keys.
  DATA lv_save       TYPE sap_bool.
  DATA lv_devclass   TYPE devclass.

  SELECT bname
    FROM usr02
    INTO TABLE @DATA(lt_users)
   WHERE bname IN @so_user
     AND class = @p_usrcls. "do not change DDIC, SAP*, etc

  LOOP AT lt_users INTO DATA(ls_user)
    WHERE bname <> 'DDIC'
      AND bname <> 'SAP*'.

    IF p_crdev = abap_true.
      PERFORM create_devclass USING ls_user-bname.
    ENDIF.

    lv_devclass = |${ ls_user-bname }|.

    ls_newcls-clsname = p_newcl.
    REPLACE '<USER>' WITH ls_user-bname INTO ls_newcls-clsname.
    WRITE: / ls_newcls-clsname.

    CHECK p_test = space.

    CALL FUNCTION 'SEO_CLASS_COPY'
      EXPORTING
        clskey       = p_class
        new_clskey   = ls_newcls
        save         = lv_save
      CHANGING
        devclass     = lv_devclass
      EXCEPTIONS
        not_existing = 1
        deleted      = 2
        is_interface = 3
        not_copied   = 4
        db_error     = 5
        no_access    = 6
        OTHERS       = 7.
    IF sy-subrc = 0.
      WRITE: 'copied'.
      lt_class_keys = VALUE #( ( ls_newcls ) ).
      CALL FUNCTION 'SEO_CLASS_ACTIVATE'
        EXPORTING
          clskeys       = lt_class_keys
        EXCEPTIONS
          not_specified = 1
          not_existing  = 2
          inconsistent  = 3
          OTHERS        = 4.
      .  IF sy-subrc = 0.
        WRITE: 'und aktiviert'.
      ENDIF.
    ELSE.
      WRITE: / ls_newcls-clsname, 'NOT copied'.
    ENDIF.


  ENDLOOP.
ENDFORM.

FORM create_devclass USING name.

  DATA lv_devclass TYPE devclass.
  DATA ls_devclass TYPE trdevclass.
  DATA lv_changed  TYPE c LENGTH 1.
  DATA lv_text     TYPE c LENGTH 80.

  ls_devclass-devclass  = |${ name }|.
  CALL FUNCTION 'TRINT_DEVCLASS_GET'
    EXPORTING
      iv_devclass        = ls_devclass-devclass
    EXCEPTIONS
      devclass_not_found = 1           " Package Does Not Exist
      OTHERS             = 2.
  IF sy-subrc = 0.
    RETURN.
  ENDIF.

  ls_devclass-ctext     = |local package for { name }|.
  ls_devclass-as4user   = name.
  ls_devclass-pdevclass = space.
  ls_devclass-dlvunit   = 'LOCAL'.
  ls_devclass-component = space.
  ls_devclass-comp_appr = space.
  ls_devclass-comp_text = space.
  ls_devclass-korrflag  = 'X'.
  ls_devclass-namespace = space.
  ls_devclass-tpclass    = space.
  ls_devclass-type       = 'N'.
  ls_devclass-target     = space.
  ls_devclass-packtype   = space.
  ls_devclass-restricted = space.
  ls_devclass-mainpack   = space.
  ls_devclass-created_by = 'COPYREPORT'.
  ls_devclass-created_on = sy-datum.

  CALL FUNCTION 'TRINT_MODIFY_DEVCLASS'
    EXPORTING
      iv_action             = 'CREA'
      iv_dialog             = space
      is_devclass           = ls_devclass
      iv_request            = space
    IMPORTING
      es_devclass           = ls_devclass
      ev_something_changed  = lv_changed
    EXCEPTIONS
      no_authorization      = 1
      invalid_devclass      = 2
      invalid_action        = 3
      enqueue_failed        = 4
      db_access_error       = 5
      system_not_configured = 6
      OTHERS                = 7.
  IF sy-subrc > 0.
    MESSAGE i000(oo) WITH 'error creating package' lv_devclass.
    STOP.
  ELSE.
    WRITE: / 'Package created:', name, lv_text.
  ENDIF.
ENDFORM.                    "create_devclass
