(namespace (read-msg 'ns))

(module colorblock-market GOVERNANCE
  @doc "module for \
      \1. helping users release items into market for sale \
      \2. supporting pricing and trading efficiently. "

  (use coin [ details ])
  (use colorblock)

  ; -------------------------------------------------------
  ; Schemas and Tables

  (defschema deal-schema
    @doc  " Record every deal of token in market \
          \ Column definitions: \
          \   @key: the combined key token:account for index \
          \   token: the token asset id \
          \   seller: current seller \
          \   price: item price \
          \   total: total amount \
          \   remain: remain amount \
          \   open: true - open, false - close "
    token:string
    seller:string
    price:decimal
    total:decimal
    remain:decimal
    open:bool
  )

  (deftable deals:{deal-schema})

  (defschema purchase-schema
    @doc  " Record every purchase of token in market \
          \ Column definitions: \
          \   @key: the hashed key \
          \   token: the token asset id \
          \   buyer: the user who purchased \ 
          \   seller: the user who sold \
          \   price: item transaction price \
          \   amount: purchase amount "
    token:string
    buyer:string
    seller:string
    price:decimal
    amount:decimal
  )

  (deftable purchases:{purchase-schema})

  ; -------------------------------------------------------
  ; Capabilities

  (defcap GOVERNANCE ()
    @doc " Only support upgrading by admin "
    (enforce-guard (at 'guard (coin.details "colorblock-admin")))
  )

  (defcap RELEASE:bool 
    ( token:string
      seller:string 
      price:decimal
      amount:decimal
    )
    @doc "Notifies release of TOKEN owned by SELLER, partially or fully"
    @event

    (enforce 
      (< 0.0 price)
      "Price must larger than zero"
    )
    (valid-price-precision price)
    (enforce-unit token amount)

    (let 
      ((balance (colorblock.get-balance token seller)))
      (enforce 
        ( > 
          balance
          0.0
        )
        "Seller has no balance of this token"
      )
      (enforce 
        ( <= 
          balance
          amount
        )
        "Amount cannot be larger than balance"
      )
    )
    (with-default-read deals (key token seller)
      { "open" : false }
      { "open" := open }
      (enforce
        (= false open)
        "Item is already on sale"
      )
    )
  )

  (defcap RECALL:bool 
    ( token:string
      seller:string 
    )
    @doc "Notifies recall of TOKEN owned by SELLER"
    @event

    (with-read deals (key token seller)
      { "open" := open }
      (enforce
        (= true open)
        "Deal status is closed"
      )
    )
  )

  (defcap PURCHASE:bool 
    ( token:string
      buyer:string 
      seller:string
      amount:decimal
    )
    @doc "Notifies purchase of TOKEN from SELLER to BUYER"
    @event

    (enforce-unit token amount)
    (with-read deals (key token seller)
      { "remain" := remain,
        "open" := open 
      }
      (enforce
        (<= amount remain)
        "Purchase amount cannot be larger than remain amount"
      )
      (enforce
        (!= seller buyer)
        "Buyer cannot be seller"
      )
      (enforce
        (= true open)
        "Deal status is closed"
      )
    )
  )


  ; -------------------------------------------------------
  ; Constants

  (defconst COLORBLOCK_MARKET_POOL "colorblock-market-pool"
    "The official account of colorblock market pool"
  )

  (defconst FEES_RATE 0.01
    "The rate of fees that platform taking"
  )

  (defconst PRICE_PRECISION 12
    "The precision of sale price"
  )

  ; -------------------------------------------------------
  ; Constants

  (defun valid-price-precision (amount:decimal)
    (enforce
      (= (floor amount PRICE_PRECISION) amount)
      "precision violation"
    )
  )


  ; -------------------------------------------------------
  ; Marketing Functions

  (defun colorblock-market-guard ()
    (create-module-guard 'colorblock-market-guard)
  )

  (defun release:string
    ( token:string
      account:string
      price:decimal
      amount:decimal
    )
    @doc " Release item for sale."
    (with-capability (RELEASE token account price amount)
      ; Transfer token to platform
      (install-capability (colorblock.TRANSFER token account COLORBLOCK_MARKET_POOL amount))
      (colorblock.transfer-create token account COLORBLOCK_MARKET_POOL (colorblock-market-guard) amount)
      (write deals (key token account) {
        "token" : token,
        "seller" : account,
        "price" : price,
        "total" : amount,
        "remain" : amount,
        "open" : true
      })
    )
  )

  (defun recall:string
    ( token:string
      account:string
    )
    @doc " Recall item and stop selling."
    (with-capability (RECALL token account)
      (let* 
        (
          (deal (read deals (key token account)))
          (remain-amount (at 'remain deal))
        )
        ; Check ownership
        (install-capability (colorblock.MINT token account))
        (validate-ownership token account)

        ; Transfer token back
        (if
          (>
            remain-amount
            0.0
          )
          [
            (install-capability (colorblock.TRANSFER token COLORBLOCK_MARKET_POOL account remain-amount))
            (colorblock.transfer token COLORBLOCK_MARKET_POOL account remain-amount)
          ]
          "no need to transfer token"
        )
        (update deals (key token account) {
          "total": 0.0,
          "remain": 0.0,
          "open": false
        })
      )
    )
  )

  (defun purchase-new-account:string
    ( token:string
      buyer:string
      seller:string
      amount:decimal
      guard:guard
    )
    @doc " Create account and purchase item"
    (colorblock.create-account-maybe token buyer guard)
    (purchase token buyer seller amount)
  )

  (defun purchase:string 
    ( token:string
      buyer:string
      seller:string
      amount:decimal
    )
    @doc " Purchase item."

    ; validate receiver first
    (install-capability (colorblock.MINT token buyer))
    (validate-ownership token buyer)

    (with-capability (PURCHASE token buyer seller amount)
      (with-read deals (key token seller)
        { "price" := price,
          "total" := total-amount
        }
        (let* 
          (
            (sale-price (* price amount))
            (fees (* FEES_RATE sale-price))
            (total-price (+ fees sale-price))
            (balance (coin.get-balance buyer))
            (remain-amount (- total-amount amount))
            (purchase-info {
              "token": token,
              "buyer": buyer,
              "seller": seller,
              "price": price,
              "amount": amount
            })
            (purchase-plus (+ {'remain: remain-amount} purchase-info))
            (hash-id (hash (+ purchase-plus (chain-data))))
          )
          (enforce 
            (<= total-price balance)
            "Insufficient balance"
          )
          (install-capability (coin.TRANSFER buyer seller price))
          (install-capability (coin.TRANSFER buyer COLORBLOCK_MARKET_POOL fees))
          (install-capability (colorblock.TRANSFER token COLORBLOCK_MARKET_POOL buyer amount))
          (coin.transfer buyer seller price)
          (coin.transfer buyer COLORBLOCK_MARKET_POOL fees)
          (colorblock.transfer token COLORBLOCK_MARKET_POOL buyer amount)
          (update deals (key token seller) {
            "remain": remain-amount
          })
          (if
            (= 0.0 remain-amount)
            (update deals (key token seller) {
              "open": false
            })
            "no need to close deal"
          )
          (insert purchases hash-id purchase-info)
        )
      )
    )
  )

  (defun item-sale-status:{deal-schema} (token:string account:string)
    (read deals (key token account))
  )


  ; -------------------------------------------------------
  ; Utility Functions

  (defun init-market-account ()
    @doc " Create market account with module guard."
    (coin.create-account COLORBLOCK_MARKET_POOL (colorblock-market-guard))
  )

  (defun deal-details (key:string)
    (read deals key)
  )
  (defun purchase-details (key:string)
    (read purchases key)
  )

  ; -------------------------------------------------------
  ; Transaction Logs
  (defun deals-txlog (tx-id:integer)
    (map (at 'key) (txlog deals tx-id))
  )
  (defun purchases-txlog (tx-id:integer)
    (map (at 'key) (txlog purchases tx-id))
  )
  (defun all-txlog (tx-id:integer)
    {
      "items": (colorblock.items-txlog tx-id),
      "ledger": (colorblock.ledger-txlog tx-id),
      "deals": (deals-txlog tx-id),
      "purchases": (purchases-txlog tx-id)
    }
  )

)


(if (read-msg "upgrade")
  ["upgrade"]
  [
    (create-table deals)
    (create-table purchases)
    (init-market-account)
  ]
)
