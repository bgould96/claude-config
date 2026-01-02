Enter planning mode.

Use the gh cli to read existing PR comments. Resolve pending issues.

If you choose not to apply a suggested fix, create a GitHub Issue to track the future work

Leave a REPLY to each comment summarizing the fix. Include  "@gemini-code-assist verify fix" at the end to trigger a re-review of that issue.

Commit and push BEFORE leaving a comment.

DO NOT add new comments directly. ONLY reply to existing threads.

After the verify fix comment, gemini-code-assist may reply asking for a further fix OR saying that the fix was not performed. 
Perform this additional fix if applicable, or explain why it's complete. Leave your reply to any such comments in the same thread and tag gemini-code-assist.

## gh CLI Reference

### Get PR review comments
```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments
```

### Reply to a specific review comment
```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies -f body="Your reply message"
```

The `comment_id` is the numeric `id` field from the comments API response.
