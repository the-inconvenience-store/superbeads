# Design: Approval flow

The client shows an approval button to administrators. Any project member can call the approval endpoint, which trusts the request's `isAdmin` field. The client immediately displays the record as approved and retries failures in the background. This implements `APPROVAL-AUTHORITY`.
