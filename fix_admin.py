p = r"D:\projects\opencode\suq\server\src\routes\admin.ts"
s = open(p).read()
old = 'adminRouter.use(requireAdmin);\n  "/admins/:id",'
new = 'adminRouter.use(requireAdmin);\n\nadminRouter.patch(\n  "/admins/:id",'
assert old in s, "old not found"
s = s.replace(old, new, 1)
open(p, "w").write(s)
print("done")
