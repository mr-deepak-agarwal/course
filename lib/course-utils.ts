/** "Day 3: Strings & Formatting" -> "Strings & Formatting" (the Day label is shown separately). */
export function stripDayPrefix(title: string): string {
  return title.replace(/^\s*Day\s+\d+\s*[:\-—]\s*/i, "");
}

export type EnrollmentStatus = "pending" | "approved" | "rejected";
