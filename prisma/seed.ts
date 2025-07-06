// Prisma seed script
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  // Create a default user for development
  const defaultUser = await prisma.user.upsert({
    where: { email: 'default@example.com' },
    update: {},
    create: {
      id: 'default-user',
      email: 'default@example.com',
      name: 'Default User',
    },
  });

  console.log('Created default user:', defaultUser);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
