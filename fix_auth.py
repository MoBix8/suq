p = r"D:\projects\opencode\suq\server\src\routes\auth.ts"
s = open(p).read()
old = '''  }),
);

'''
new = '''  }),
);

authRouter.post(
  "/logout",
  requireAuth,
  asyncHandler(async (req, res) => {
    const auth = req.auth!;
    if (auth.role === "OWNER" && auth.shopId) {
      await prisma.shop.update({
        where: { id: auth.shopId },
        data: { boundDeviceId: null },
      });
      if (auth.deviceId) {
        await prisma.device.deleteMany({
          where: { shopId: auth.shopId, deviceId: auth.deviceId },
        });
      }
    }
    res.json({ ok: true });
  }),
);
'''
assert old in s
s = s.replace(old, new, 1)
open(p, "w").write(s)
print("done")
