self: super:
{
  lxcfs = super.lxcfs.overrideAttrs (oldAttrs: rec {
    src = super.fetchFromGitHub {
      owner = "aither64";
      repo = "lxcfs";
      rev = "33da5e5f71154ed69f17896a6271563914951dde";
      sha256 = "1yv1qq3wv5xmj1nmd6nx1l9q1d4f6aasm1xbn7r8lrpwwdmpirjz";
    };
  });
}
