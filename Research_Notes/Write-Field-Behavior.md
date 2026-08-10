# SKY API write-field behavior: measured behavior

Central research notes for how the SKY API treats the fields sent in a write request body. Everything below
was **measured against a live tenant**, not inferred from documentation or from how other endpoints behave.

- Tenant: `SKY Developer Cohort` (development), `SKY Developer Cohort Environment 1`
- Dates measured: 2026-08-03 (validation survey, §3), 2026-08-10 (type coercion and field naming, §1 and §2)
- Test records: users `2888534` and `3178514` (relationship tests), user `3294459` (Mikey Davis, update tests)

> **The API is far more permissive than its schema.** It does not reject a wrong JSON type, it does not
> validate the values of most string fields, and it does not always name a field the same way on the way in
> and on the way out. A write that returns success is not evidence that the intended value was stored. Verify
> every new write field by reading it back with `-ReturnRaw`.

## 1. Wrong JSON types are coerced, not rejected

A value whose JSON type does not match the schema's declared type is **converted to the declared type and
stored**, silently and with a success response. It is not rejected, and no warning is returned.

Measured on `POST /school/v1/users/{user_id}/relationships`, whose `RelationshipCreate.comments` is declared
`string` in the OpenAPI schema:

| Sent in the request body | HTTP result | Value stored (read back) |
|---|---|---|
| `"comments": false` | 200, success | `"false"` (a 5-character string) |
| `"comments": ""` | 200, success | `""` (empty) |
| `comments` key omitted entirely | 200, success | `""` (empty) |
| `"comments": "CONTROL TEST 12345"` | 200, success | `"CONTROL TEST 12345"` |

So the boolean `false` became the text `false`. This is what a Newtonsoft-style deserializer does with a
boolean bound to a string property; a stricter parser would have returned 400.

**This caused a real bug.** `Set-SchoolUserRelationship` defaulted its `comments` field to `$false` alongside
the six genuinely boolean options next to it, so every relationship it created without `-comments` got the
literal text `false` in its Notes/Comments field. Fixed in 0.5.1; see the changelog.

**Implication:** a wrong-typed default is invisible in testing unless you read the value back. Do not rely on
a 200 response, and do not assume PowerShell's `ConvertTo-Json` output shape is harmless because the call
succeeded. Note also that `ConvertTo-Json` emits `$false` as a JSON boolean `false`, not as the string
`"False"` that PowerShell's own string conversion would produce; the conversion to text happens server-side.

## 2. Request and response field names do not always match

The relationship endpoints name the same value differently depending on direction:

| Direction | Endpoint | Field name |
|---|---|---|
| Write | `POST /school/v1/users/{user_id}/relationships` | `comments` (plural) |
| Read | `GET /school/v1/users/{user_id}/relationships` | `comment` (singular) |

Raw GET payload for a relationship created with `-comments 'CONTROL TEST 12345'`:

```json
{"comment":"CONTROL TEST 12345","contact":true,"first_name":"Thomas","last_name":"Ajayi",
 "list_as_parent":false,"parental_access":false,"primary":false,"relationship":58,
 "resides_with":false,"show_parent":false,"tuition_responsible_signer":false,
 "type_id":2,"user_one_id":3178514,"user_one_role":"Sibling","user_two_id":2888534}
```

Consequence for callers:

```powershell
(Get-SchoolUserRelationship -User_ID $id).comments   # always $null, the property does not exist
(Get-SchoolUserRelationship -User_ID $id).comment    # the actual stored value
```

This is the API's own asymmetry, not a module transformation; the module returns the API objects as they
arrive.

**Implication:** this is an easy way to draw a wrong conclusion. Reading `.comments` back returns `$null` for
every relationship, which looks exactly like "the field was stored empty" and hides a wrong value. When
verifying any write, confirm the read-back path works by writing a distinctive marker string first, then
testing the real case.

## 3. String field values are not validated (measured 2026-08-03)

`PATCH /school/v1/users` (`Update-SchoolUser`) accepts values its own documentation does not list, and stores
malformed ones verbatim:

| Written to `living_status` | Result |
|---|---|
| `Remarried` | Accepted and stored. Offered by the web GUI, absent from the endpoint's documented value list. |
| `Marrieed` (a typo) | Accepted and stored verbatim. No validation at all. |
| `ZZNotARealStatus` | Accepted, silently **truncated to 10 characters**, success returned. |

The schema's prose "Valid values are ..." lists are therefore neither complete nor enforced. Before trusting
a documented value list, check the GUI dropdown and test-write the value. Expect written-but-unvalidated
fields to need a module-side `ValidateSet` as the only real guardrail.

This is the behavior that `Update-SchoolUser -Validate` exists to catch: the endpoint returns success without
validating the payload, so an unsupported value can report as updated while changing nothing.

### Fields that cannot be verified at all

`summary_note` is returned by no read endpoint. A written value appears in neither the basic
(`Get-SchoolUser`) nor the extended (`Get-SchoolUserExtended`) user read, so there is nothing to compare a
write against. `-Validate` reports it as unverifiable rather than comparing it.

## 4. How to test a write field safely

The pattern used for the measurements above, against the development tenant only:

1. **Guard the environment.** After `Connect-SKYAPI`, call `Get-SKYAPIContext` and confirm
   `legal_entity_name` is `SKY Developer Cohort`. Throw before any write if it is not. Production tenants
   hold real school data.
2. **Capture the wire body without sending it.** Shim the private POST/PATCH helper in module scope to record
   `ConvertTo-Json $params` and return. The shim and the call under test must live in the **same**
   `& (Get-Module SKYAPI) { ... }` scriptblock: a function defined inside that block is local to that
   invocation and is gone once it returns.
3. **Prove the read-back path.** Write a distinctive marker string and confirm it comes back, so a `$null`
   read cannot be mistaken for an empty store (see §2).
4. **Read back with `-ReturnRaw`** and inspect the raw JSON, not the shaped object. Check the property's
   presence, .NET type and length, not just its display value: an empty string and the text `false` both look
   unremarkable when interpolated into a message.
5. **Record the baseline and restore it.** Capture the record counts before the test and assert they match
   afterwards, with the removal in a `finally` block.

A note on harness construction: assigning a helper's output to `$null` discards **everything** the helper
wrote to the output stream, including the diagnostics. Write diagnostics with `Write-Host` and return only
the data, or the test will appear to pass while telling you nothing. The same lesson applies to counters; see
the harness warning in `Research_Notes/DateTime-Handling.md`.
