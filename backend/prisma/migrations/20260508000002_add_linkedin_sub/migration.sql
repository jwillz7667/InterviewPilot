-- AlterTable
ALTER TABLE "users" ADD COLUMN "linkedinSub" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "users_linkedinSub_key" ON "users"("linkedinSub");
