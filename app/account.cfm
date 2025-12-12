<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Account Settings</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">

  <!-- Bootstrap 5 CSS (CDN) -->
  <link
    href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
    rel="stylesheet"
    integrity="sha384-QWTKZyjpPEjISv5WaRU9OFeRpok6YctnYmDr5pNlyT2bRjXh0JMhjY6hW+ALEwIH"
    crossorigin="anonymous">

  <link rel="stylesheet" href="/fpw/assets/css/app.css">

  <!-- Defensive: ensure brand is visible even if app.css overrides anchors -->
  <style>
    .navbar .navbar-brand {
      display: inline-block !important;
      color: #fff !important;
      opacity: 1 !important;
      visibility: visible !important;
      font-weight: 600;
    }
  </style>
</head>

<body class="bg-light">

<nav class="navbar navbar-expand-lg navbar-dark bg-primary mb-3">
  <div class="container-fluid">

    <!-- Brand -->
    <a class="navbar-brand" href="/fpw/app/dashboard.cfm">Mobile App</a>

    <!-- Toggler (mobile) -->
    <button class="navbar-toggler" type="button"
            data-bs-toggle="collapse" data-bs-target="#mainNav"
            aria-controls="mainNav" aria-expanded="false" aria-label="Toggle navigation">
      <span class="navbar-toggler-icon"></span>
    </button>

    <!-- Collapsible content -->
    <div class="collapse navbar-collapse" id="mainNav">

      <ul class="navbar-nav me-auto mb-2 mb-lg-0">
        <li class="nav-item">
          <a class="nav-link" href="/fpw/app/dashboard.cfm">Dashboard</a>
        </li>
        <li class="nav-item">
          <a class="nav-link active" aria-current="page" href="/fpw/app/account.cfm">Account</a>
        </li>
      </ul>

      <div class="d-flex gap-2">
        <a class="btn btn-outline-light btn-sm" href="/fpw/app/dashboard.cfm">Dashboard</a>
        <button class="btn btn-outline-light btn-sm" id="logoutButton" type="button">Logout</button>
      </div>

    </div>
  </div>
</nav>

<div class="container pb-5">

  <div class="row">
    <div class="col-12">
      <h1 cla
