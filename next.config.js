/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // make sure the optional logo/signature files are bundled with the serverless functions
  experimental: {
    outputFileTracingIncludes: {
      "/api/certificate/[code]": ["./public/codeq-logo.png", "./public/signature.png"],
      "/verify/[code]": ["./public/codeq-logo.png", "./public/signature.png"],
    },
  },
};

module.exports = nextConfig;
