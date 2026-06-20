
payments-api (8001) — blueprint prefixes inferred from paths:

Method      Path                                Handler         Auth     High-attention  
---------------------------------------------------------------------------------------------
POST        /v1/auth/register                   register        🔓      rate-limiting (V-APP-08)
---------------------------------------------------------------------------------------------
POST        /v1/auth/login                      login           🔓      rate-limiting, password hash
---------------------------------------------------------------------------------------------
POST        /v1/auth/otp                        otp             🔓      rate-limiting
---------------------------------------------------------------------------------------------
GET         /v1/accounts/                       list_accounts   ✅          
---------------------------------------------------------------------------------------------
GET         /v1/accounts/{id}                   get_account     ✅      IDOR (V-APP-03)
---------------------------------------------------------------------------------------------
PUT         /v1/accounts/{id}/profile           update_profile  ✅      mass assignment (V-APP-07)
---------------------------------------------------------------------------------------------
GET         /v1/transactions/search?q=          search          ✅      SQLi (V-APP-01)
---------------------------------------------------------------------------------------------
GET         /v1/transactions/{reference}        get_txn         ✅  
---------------------------------------------------------------------------------------------
POST        /v1/wallets/{account_id}/credit     credit          ✅
---------------------------------------------------------------------------------------------
POST        /v1/wallets/{account_id}/debit      debit     ✅  race condition (V-APP-05), audit log (V-APP-11)
----------------------------------------------------------------------------------------------
POST        /v1/webhooks/                   register_webhook    ✅
-----------------------------------------------------------------------------------------------
POST        /v1/webhooks/test                   test_webhook    ✅      SSRF (V-APP-04)
-----------------------------------------------------------------------------------------------
GET         /v1/admin/users                     list_users      ✅      authZ — is "admin only" enforced?
------------------------------------------------------------------------------------------------
POST        /v1/admin/session/restore           restore_session ✅      insecure deserialisation (V-APP-10)


kyc-api (8002):
Method      Path                        Handler         Auth     High-attention
------------------------------------------------------------------------------------------------
POST        /v1/verify/bvnve            rify_bvn        ✅      SSRF variant (provider URL)
------------------------------------------------------------------------------------------------
GET         /v1/verify/lookup           lookup          ✅      SQLi variant (V-APP-01)
------------------------------------------------------------------------------------------------
POST        /v1/documents/upload        upload          ✅ 
------------------------------------------------------------------------------------------------
GET         /v1/documents/{key}         fetch_doc       ✅      IDOR variant (V-APP-03), path traversal?   
                                                                (<path:key>)