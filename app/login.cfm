<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Mobile App Login</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <!-- Bootstrap 5 CSS (CDN) -->
    <link
        href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
        rel="stylesheet"
        integrity="sha384-QWTKZyjpPEjISv5WaRU9OFeRpok6YctnYmDr5pNlyT2bRjXh0JMhjY6hW+ALEwIH"
        crossorigin="anonymous">

    <!-- Your custom CSS (optional) -->
    <link rel="stylesheet" href="/fpw/assets/css/app.css">

    <style>
        body {
            min-height: 100vh;
        }
        .login-wrapper {
            min-height: 100vh;
        }
    </style>
</head>
<body class="bg-light d-flex align-items-center justify-content-center">

<div class="container login-wrapper">
    <div class="row justify-content-center">
        <div class="col-12 col-sm-10 col-md-6 col-lg-4">
            <div class="card shadow-sm">
                <div class="card-body p-4">
                    <h1 class="h4 mb-3 text-center">Mobile App Login</h1>
                    <p class="text-muted small text-center mb-3">
                        This form logs in via the <code>/fpw/api/v1/auth.cfm</code> endpoint.
                    </p>

                    <div id="loginAlert" class="alert d-none" role="alert"></div>

                    <form id="loginForm" novalidate>
                        <div class="mb-3">
                            <label for="email" class="form-label">Email address</label>
                            <input
                                type="email"
                                class="form-control"
                                id="email"
                                name="email"
                                required
                                autocomplete="username"
                            >
                        </div>

                        <div class="mb-3">
                            <label for="password" class="form-label">Password</label>
                            <input
                                type="password"
                                class="form-control"
                                id="password"
                                name="password"
                                required
                                autocomplete="current-password"
                            >
                        </div>

                        <button type="submit" class="btn btn-primary w-100" id="loginButton">
                            Sign In
                        </button>
                    </form>
                </div>
            </div>

            <div class="mt-3 small">
  <a href="/fpw/app/forgot-password.cfm">Forgot password?</a>
</div>

            <p class="text-center text-muted small mt-3">
                &copy; #dateFormat(now(), "yyyy")# Mobile App Example
            </p>
        </div>
    </div>
</div>

<!-- Bootstrap 5 JS bundle (CDN) -->
<script
    src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"
    integrity="sha384-YvpcrYf0tY3lHB60NNkmXc5s9fDVZLESaAA55NDzOxhy9GkcIdslK1eN7N6jIeHz"
    crossorigin="anonymous"></script>

<!-- Your app JS (note the /fpw prefix) -->
<script src="/fpw/assets/js/app/api.js"></script>
<script src="/fpw/assets/js/app/core.js"></script>

</body>
</html>
