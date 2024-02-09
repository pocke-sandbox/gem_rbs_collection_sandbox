require_relative "./utils"

def gem_accepted?(gem, approvers)
  reviewers = gem_reviewers(gem, BASE_SHA)

  # If reviewers is empty, it means that anyone cannot approve this PR.
  # So, we can merge this PR without approval.
  return true if reviewers.empty?

  # If the author is a reviewer, they can merge this PR themselves.
  return true if reviewers.include?(PR_AUTHOR)

  not (reviewers & approvers).empty?
end

def non_gem_accepted?(approvers)
  admins = administorators.map { _1['login'] }

  not (approvers & admins).empty?
end

def approved?(changed_gems, changed_non_gems, pr_number)
  approvers = approvements(HEAD_SHA, pr_number).map { _1['user']['login'] }

  is_approved = true

  # Check gem files
  not_approved_gems = changed_gems.reject { |gem| gem_accepted?(gem, approvers) }
  unless not_approved_gems.empty?
    puts "The following gems are not approved yet:"
    puts not_approved_gems.join("\n")
    is_approved = false
  end

  # Check non gem files
  if !changed_non_gems.empty? && !non_gem_accepted?(approvers)
    puts "The following files are changed, but not approved by the admin yet:"
    puts changed_non_gems.join("\n")
    is_approved = false
  end

  is_approved
end

def can_merge_by?(commented_by, author, gem_reviewers)
  return true if commented_by == author
  return true if administorators.include?(commented_by)
  return true if gem_reviewers.include?(commented_by)
  return false
end

def all_gem_reviewers(changed_gems)
  changed_gems.flat_map { |gem| gem_reviewers(gem, BASE_SHA) }
end

def comment_to_github(body, pr_number)
  sh! 'gh', 'pr', 'comment', pr_number, '--body', body, '--repo', GH_REPO
end

changed_gems = JSON.parse(ARGV[0])
changed_non_gems = JSON.parse(ARGV[1])
pr_number = ARGV[2]

reviewers = all_gem_reviewers(JSON.parse(ARGV[0]))
unless can_merge_by?(ENV['COMMENTED_BY'], PR_AUTHOR, reviewers)
  body = <<~BODY
    `/merge` command failed.

    You do not have permission to merge this PR.
    PR author, reviewers, and administrators can merge this PR.
  BODY
  comment_to_github(body, pr_number)
  exit 1
end

unless approved?(changed_gems, changed_non_gems, pr_number)
  body  = <<~BODY
    `/merge` command failed.

    This PR is not approved yet by the reviewers. Please get approval from the reviewers.
    See the Actions tab for detail.
  BODY
  comment_to_github(body, pr_number)
  exit 1
end
